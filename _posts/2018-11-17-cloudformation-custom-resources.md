---
layout: post
title:  "Plug gaps in Cloudformation with Custom Resources"
date:   2018-11-17
categories: cloudformation
author: gojko
image: "https://effortless-serverless.com/images/serverless-migration/figure-2.jpg"
---

CloudFormation is the key deployment technology in the AWS world, and the underlying magic behind many higher level deployment tools such as AWS SAM or the Serverless Framework.Unfortunately, due to the break-neck speed of AWS service updates, CloudFormation often lacks support for newer options. For example, at the time when I wrote this in November 2018, AWS Pinpoint was not supported at all. Some services, such as Cognito User Pools, are partially supported. You can presently create User Pools with CloudFormation, but you can't set up the [built-in UI](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-ux.html) or configure an authentication domain.

To fully use the latest AWS features, teams often need to mix automated deployments with manual manual work or some other scripting. This is where Custom Resources come in: they help you fill the gaps in CloudFormation. This means that you don't have to choose between version controlled infrastructure and brand new features. And because most other tools build on top of CloudFormation, you can patch up and extend most other deployment utilities to support your specific needs as well. 

In this tutorial, I'll show you how to create a custom CloudFormation resource to fully automate the deployment of a currently unsupported service. We'll use AWS Pinpoint for the example. 

## Custom Resources under the hood

A Custom Resource is a way to delegate a deployment step to somewhere outside the internal AWS CloudFormation system. You can declare a custom resource similarly to any other deployment entity, with all the usual parameters and references, and CloudFormation will track the status as it would for any internal AWS Resource. Instead of internally processing the requested changes, it will just send a request to you. You then have to handle the work somehow, and upload the status of the task back to CloudFormation. 

Similarly to most other types of callbacks and triggers in AWS, the integration point for Custom Resources in CloudFormation is a Lambda function. This means that you can use a Lambda function to set up or configure additional resources. From the Lambda function, you can use the AWS SDK which fully tracks public feature releases, and support new resource types of features while the CloudFormation platform developers catch up.

To tell CloudFormation that you want to handle the resource yourself, start the resource type with `Custom::`. Here's how our Pinpoint will start:

```yml
PinpointApplication:
  Type: 'Custom::PinpointApp'
```

You can then add any parameters needed for the application, as usual in the `Properties` key-value map. CloudFormation will just pass these parameters to your task. You can still use all the usual CloudFormation references, functions and variables. For example, in order to create a Pinpoint application, we need to give it a name. This could be a usual CloudFormation parameter:

```yml
AWSTemplateFormatVersion: '2010-09-09'

Parameters:

  AppName: 
    Type: String

Resources:

  PinpointApp:
    Type: 'Custom::PinpointApp'
    Properties:
      Name: !Ref AppName
```

The final piece of the puzzle is to tell CloudFormation where to send the custom task request. To do that, you'll need to add a `ServiceToken` property for the Lambda function:

```yml
PinpointApp:
  Type: 'Custom::PinpointApp'
  Properties:
    Name: !Ref AppName
    ServiceToken: <SOME LAMBDA FUNCTION ARN>
```

The nice thing about CloudFormation templates is that you can actually create the Lambda function to process the custom resource in the same template as the resource itself. That's our next step.

## Wiring up custom resources

We'll need to add two more resources to the Cloudformation template. The first is the IAM policy allowing the custom Lambda function to create resources in your account. As custom resources can be a bit fiddly to set up, I strongly suggest letting the Lambda function log to Cloudwatch, and potentially setting up [AWS CloudTrail](https://aws.amazon.com/cloudtrail/getting-started/) or a dead-letter queue to send you notifications about potential failures. That way, you'll be able to capture task requests and manually handle them if your Lambda explodes during development.

Here is a basic IAM role that will do for now. It lets the function log to CloudWatch, create and delete Pinpoint applications.

```yml
PinpointConfigurationLambdaRole:
  Type: 'AWS::IAM::Role'
  Properties:
    AssumeRolePolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Action: 'sts:AssumeRole'
          Principal:
            Service: lambda.amazonaws.com
    Policies:
      - PolicyName: WriteCloudWatchLogs
        PolicyDocument: 
          Version: '2012-10-17'
          Statement: 
            - Effect: Allow
              Action:
                - 'logs:CreateLogGroup'
                - 'logs:CreateLogStream'
                - 'logs:PutLogEvents'
              Resource: 'arn:aws:logs:*:*:*'
      - PolicyName: UpdatePinpoint
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action: 
                - 'mobiletargeting:CreateApp'
                - 'mobiletargeting:DeleteApp'
              Resource: '*'
```

The function itself also needs a CloudFormation resource. This is just a standard [AWS::Lambda::Function](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-lambda-function.html) resource. I suggest increasing the default timeout so your function has time to act on resources properly. This is where you could set up a dead-letter queue if you're not using CloudTrail.

```yml
PinpointConfigurationLambdaFunction:
  Type: 'AWS::Lambda::Function'
  Properties:
    Role: !GetAtt PinpointConfigurationLambdaRole.Arn
    Timeout: 300
    Runtime: <LAMBDA RUNTIME>
    Code: <LAMBDA CODE DIR>
    Handler: <LAMBDA ENTRY POINT>
```

We can wire this function into the custom resource using the CloudFormation `GetAtt` function to extract the ARN:

```yml
PinpointApp:
  Type: 'Custom::PinpointApp'
  Properties:
    Name: !Ref AppName
    ServiceToken: !GetAtt PinpointConfigurationLambdaFunction.Arn
```

## Custom Resource requests

We can now create the Lambda function to handle the custom task. The function will get an event with all the configured properties in the `ResourceProperties` field. So, for example, the result of the parameter mapping above will end in `event.ResourceProperties.Name`. 

The `RequestType` field tells us what CloudFormation needs to do with the resource. The values can be `Create`, `Update` and `Delete`, which are all self-explanatory. 

After the creation, we'll need to give CloudFormation the unique identifier for the new resource -- or a "physical resource ID" in CloudFormation jargon. During updates and deletes, CloudFormation will send this identifier back to us in the `PhysicalResourceId` property. In this case, we're creating an app inside Pinpoint which will give us the ID back, so that's a logical choice for the physical resource ID. We'll need to extract this from the AWS SDK API responses.  

I will use a Node function as that's easy to set up, but you can use any supported Lambda runtime. The start of the function will use the AWS SDK for Pinpoint to manage the resource, and just return back the response from the API. 

```js
// pinpoint.js
const aws = require('aws-sdk'),
 pinpoint = new aws.Pinpoint(),
 createApp = function (name) {
  const params = {
   CreateApplicationRequest: {
    Name: name
   }
  };
  return pinpoint.createApp(params).promise()
   .then(result => result.ApplicationResponse);
 },
 deleteApp = function (id) {
  return pinpoint.deleteApp({ApplicationId: id}).promise()
   .then(result => result.ApplicationResponse);
 },
 extractResourceId = (event, result) => result.Id || event.PhysicalResourceId,
 handleEvent = function (event) {
  const requestType = event.RequestType;
  if (requestType === 'Create') {
   return createApp(event.ResourceProperties.Name);
  } else if (requestType === 'Update') {
   return pinpoint.deleteApp(event.PhysicalResourceId)
    .then(() => createApp(event.ResourceProperties.Name));
  } else if (requestType === 'Delete') {
   return deleteApp(event.PhysicalResourceId);
  }
 };

module.exports = {
  handleEvent: handleEvent,
  extractResourceId: extractResourceId
}
```

## Custom resource responses

CloudFormation expects the response in a specific JSON structure. 

The `Status` field should be either `SUCCESS` or `FAILED`, depending on the outcome of the task. 

The `PhysicalResourceId` needs to be the unique identifier of the resource we created. Even if you're doing something transient, it's important to provide some value here, otherwise CloudFormation will fail the task and report an invalid resource ID. This is specifically important in case of errors, because any underlying error will just be masked by CloudFormation complaining about IDs. If you don't know what to put here, it's a good bet to use the `awsRequestId` from the Lambda execution context. This will be reasonably unique between resource calls, and in case of temporary errors for the same resource, Lambda will actually give you the same request ID. 

It's very important to send this ID back consistently after all operations. For example, if you send a different physical ID after an update, CloudFormation will also send a delete message request for the previous resource ID. This is a good way of handling resources which can't be updated, but need to be created again. So make sure to reuse the old resource ID in case of updating a resource.

CloudFormation uses three fields for validation: `StackId`, `RequestId` and `LogicalResourceId`. You need to just copy these directly from the originating event.

Finally, you can put any output values into the `Data` field in case of a successful result, or a message in the `Reason` field in case of errors.

Unfortunately, CloudFormation won't just take the result of a Lambda function. Instead, it will wait for the response to be uploaded to a specific S3 location, provided in the incoming event `ResponseURL` parameter. The value of that field will be a pre-signed S3 resource URL that will only accept a HTTPS `PUT` request.

Here is a utility class to capture the generic flow. It expects a resource-specific function to process the actual event (this will be the `handleEvent` function defined above), and a function to extract the physical resource ID from the results.

```js
// processor.js
const httpsPut = require('./https-put'),
 errorSerializer = require('./error-serializer');

module.exports = function Processor(eventAction, extractResourceId) {
 const sendResult = function (event, result) {
   const responseBody = JSON.stringify({
    Status: 'SUCCESS',
    PhysicalResourceId: extractResourceId(event, result),
    StackId: event.StackId,
    RequestId: event.RequestId,
    LogicalResourceId: event.LogicalResourceId,
    Data: result
   });
   return httpsPut(event.ResponseURL, responseBody);
  },
  sendError = function (event, error) {
   console.error(error);
   const resourceId = event.PhysicalResourceId || `fail:${Date.now()}`;
   const responseBody = JSON.stringify({
    Status: 'FAILED',
    Reason: errorSerializer(error),
    PhysicalResourceId: resourceId,
    StackId: event.StackId,
    RequestId: event.RequestId,
    LogicalResourceId: event.LogicalResourceId
   });
   return httpsPut(event.ResponseURL, responseBody);
  };
 this.processEvent = function (event, context) {
  console.log('received', JSON.stringify(event)); 
  return Promise.resolve()
   .then(() => eventAction(event, context))
   .then(result => sendResult(event, result))
   .catch(e => sendError(event, e))
   .catch(e => {
    console.error(e);
    return Promise.reject(errorSerializer(e));
   });
 };
};
```

The gotcha here is that CloudFormation won't automatically fail if there is an exception during the custom resource Lambda task, or if it times out. We need to handle all those types of errors internally and then report back. That's why the `processEvent` function first starts a `Promise` chain, so we can handle exceptions, asynchronous and synchronous errors easily. 

## Utility functions

The final pieces are the two utility functions, one to perform a `PUT` request, and one to convert from an error into a string. 

For the first one, we could use some third-party module for network requests, such as `axios` or `got`, to provide network retries and content processing, but Node has all the features for a minimal implementation built in, and that does the trick for now. 

The key trick here for the CloudFormation flow (S3 in fact), is to include the 'content-length' header for the upload. If you don't do that, the upload will fail and Cloudformation gets indefinitely stuck.

```js
// https-put.js
const https = require('https'),
 urlParser = require('url');
module.exports = function httpsPut(url, body) {
 const parsedUrl = urlParser.parse(url),
  callOptions = {
   host: parsedUrl.host,
   port: parsedUrl.port,
   method: 'PUT',
   path: parsedUrl.path,
   headers: {
    'content-type': '',
    'content-length': body.length
   }
  };
 console.log('sending', callOptions, body);
 return new Promise((resolve, reject) => {
  const req = https.request(callOptions);
  req.setTimeout(10000, () => {
   const e = new Error('ETIMEDOUT');
   e.code = 'ETIMEDOUT';
   e.errno = 'ETIMEDOUT';
   e.syscall = 'connect';
   e.address = callOptions.hostname;
   e.port = callOptions.port;
   reject(e);
  });
  req.on('error', reject);
  req.on('response', (res) => {
   const dataChunks = [];
   res.setEncoding('utf8');
   res.on('data', (chunk) => dataChunks.push(chunk));
   res.on('end', () => {
    const response = {
     headers: res.headers,
     body: dataChunks.join(''),
     statusCode: res.statusCode,
     statusMessage: res.statusMessage
    };
    if ((response.statusCode > 199 && response.statusCode < 400)) {
     resolve(response);
    } else {
     reject(response);
    }
   });
  });
  req.write(body);
  req.end();
 });
};
```

For error conversion to string, we need to consider synchronous exceptions, asynchronous promise rejections, plus strings or JavaScript error objects in both cases.

```js
// error-serializer.js
module.exports = function errorSerializer(error) {
	if (!error) {
		return 'Undefined error';
	}
	if (typeof error === 'string') {
		return error;
	}
	return error.stack || error.message || JSON.stringify(error);
};
```


## Wrapping everything up

With all those parts in place, we can now simply wire everything into a Lambda function:

```js 
// lambda.js

const pinpoint = require('./pinpoint'),
 Processor = require('./processor'),
 processor = new Processor(pinpoint.handleEvent, pinpoint.extractResourceId)

exports.handler = processor.processEvent;
```

Save all those files in a directory relative to the template, say `code`, and update the lambda configuration:

```yml
PinpointConfigurationLambdaFunction:
  Type: 'AWS::Lambda::Function'
  Properties:
    Role: !GetAtt PinpointConfigurationLambdaRole.Arn
    Timeout: 300
    Runtime: nodejs8.10
    Code: ./code
    Handler: lambda.handler
```



