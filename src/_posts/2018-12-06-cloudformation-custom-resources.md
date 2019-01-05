---
layout: post
title:  "Plug gaps in CloudFormation with Custom Resources"
date: 2018-11-17 08:50:28
categories: CloudFormation
author_name : Gojko Adzic
author_url : /author/gojko
author_avatar: gojko.jpg
twitter_username: gojkoadzic
show_avatar: true
feature_image: custom-resource-4.png
show_related_posts: false
square_related: recommend-gojko
---

For AWS users, especially those that like to play with new technology, last week was like Christmas coming early. 
For many teams, using new features in production requires CloudFormation support, which comes at a much slower pace. In this tutorial, I'll show you how to patch up CloudFormation with custom resources so you do not have to choose between version controlled infrastructure and brand new features. 

The AWS SDK is built by individual product teams, so it usually keeps pace with new product features.  With Custom Resources you can use the AWS SDK to fill the gaps in CloudFormation. And because most other deployment tools work based on CloudFormation, you can patch up and extend most other deployment utilities to support your specific needs as well. 

We'll use AWS Pinpoint as an example. At the time when I wrote this, Pinpoint was still not supported in CloudFormation, but it's quite a useful service to plug into an ecosystem, especially if you are using Cognito to authenticate users.  So instead of mixing CloudFormation templates for Cognito and manually deploying Pinpoint, we'll add a custom resource to automate everything reliably.

## Custom Resources under the hood

A Custom Resource is a way to delegate a deployment step to somewhere outside the internal AWS CloudFormation system. You can declare a custom resource similarly to any other deployment entity, with all the usual parameters and references, and CloudFormation will track the status as it would for any internal AWS Resource. Instead of internally processing the requested changes, CloudFormation will just send a request to you. You then have to handle the work somehow, and upload the status of the task back to CloudFormation. 

Similarly to most other types of callbacks and triggers in AWS, the integration point for Custom Resources in CloudFormation is a Lambda function. This means that you can use a Lambda function to set up or configure additional resources. From the Lambda function, you can use the AWS SDK which fully tracks public feature releases, and support new resource types of features while the CloudFormation platform developers catch up.

To tell CloudFormation that you want to handle the resource yourself, start the resource type with `Custom::`. Here's how our Pinpoint will start:

```yml
PinpointApplication:
  Type: 'Custom::PinpointApp'
```

You can then add any parameters needed for the application in the `Properties` key-value map, as you would for built-in resources. CloudFormation will just pass these parameters to your task. You can still use all the usual CloudFormation references, functions and variables. For example, in order to create a Pinpoint application, we need to give it a name. This could be a usual CloudFormation parameter:

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

## Custom Resource requests

We can now create the Lambda function to handle the custom task. The function will get an event with all the configured properties in the `ResourceProperties` field. So, for example, the result of the parameter mapping above will end in `event.ResourceProperties.Name`. 

The `RequestType` field tells us what CloudFormation needs to do with the resource. The values can be `Create`, `Update` and `Delete`, which are all self-explanatory. 

After the creation, we'll need to give CloudFormation the unique identifier for the new resource -- or a "physical resource ID" in CloudFormation jargon. During updates and deletes, CloudFormation will send this identifier back to us in the `PhysicalResourceId` property. In this case, we're creating an app inside Pinpoint which will give us the ID back, so that's a logical choice for the physical resource ID. We'll need to extract this from the AWS SDK API responses.  

I will use a Node function as that's easy to set up, but you can use any supported Lambda runtime. The start of the function will use the AWS SDK for Pinpoint to manage the resource, and just return back the response from the API. 

```js
//pinpoint-event.js

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
 };
module.exports = function handleEvent(event/*, context*/) {
 const requestType = event.RequestType;
 if (requestType === 'Create') {
  return createApp(event.ResourceProperties.Name);
 } else if (requestType === 'Update') {
  return pinpoint.deleteApp(event.PhysicalResourceId)
   .then(() => createApp(event.ResourceProperties.Name));
 } else if (requestType === 'Delete') {
  return deleteApp(event.PhysicalResourceId);
 } else {
  return Promise.reject(`Unexpected: ${JSON.stringify(event)}`);
 }
};
```

## Custom Resource responses

CloudFormation expects the response in a specific JSON structure. 

The `Status` field should be either `SUCCESS` or `FAILED`, depending on the outcome of the task. 

The `PhysicalResourceId` needs to be the unique identifier of the resource we created. Even if you're doing something transient, it's important to provide some value here, otherwise CloudFormation will fail the task and report an invalid resource ID. This is specifically important in case of errors, because any underlying error will just be masked by CloudFormation complaining about IDs. If you don't know what to put here, it's a good bet to use the `awsRequestId` from the Lambda execution context. This will be reasonably unique between resource calls, and in case of temporary errors for the same resource, Lambda will actually give you the same request ID. 

It's very important to send this ID back consistently after all operations. For example, if you send a different physical ID after an update, CloudFormation will also send a delete message request for the previous resource ID. This is a good way of handling resources which can't be updated, but need to be created again. So make sure to reuse the old resource ID in case of updating a resource.

The Pinpoint AWS SDK returns an Id property inside the `ApplicationResponse` object, so we'll use that to pull the physical resource ID out.

```js
// result-to-app-id.js
module.exports = function resultToAppId(event, result) {
 return result.Id || event.PhysicalResourceId;
};
```

CloudFormation also uses three fields for validation: `StackId`, `RequestId` and `LogicalResourceId`. You need to just copy these directly from the originating event.

Finally, you can put any output values into the `Data` field in case of a successful result, or a message in the `Reason` field in case of errors. This allows linking the results of the custom step with other resources, for example using the Application ID in IAM policies.

Unfortunately, CloudFormation won't just take the result of a Lambda function. Yes, that is a pain, but at the moment it is as it is. Instead, CloudFormation will wait for the response to be uploaded to a specific S3 location, provided in the incoming event `ResponseURL` parameter. The value of that field will be a pre-signed S3 resource URL that will only accept a HTTPS `PUT` request.

![](/img/custom-resource-4.png)

Here is a utility class to capture the generic flow. It expects a resource-specific function to process the actual event (this will be the `handleEvent` function defined above), and a function to extract the physical resource ID from the results.

```js
//cloudformation-resource.js
const errorToString = require('./error-to-string'),
 httpsPut = require('./https-put'),
 timeout = require('./timeout');
module.exports = function (eventAction, extractResourceId) {
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
   const resourceId = event.PhysicalResourceId || `f:${Date.now()}`;
   const responseBody = JSON.stringify({
    Status: 'FAILED',
    Reason: errorToString(error),
    PhysicalResourceId: resourceId,
    StackId: event.StackId,
    RequestId: event.RequestId,
    LogicalResourceId: event.LogicalResourceId
   });
   return httpsPut(event.ResponseURL, responseBody);
  };
 this.processEvent = function (event, context) {
  console.log('received', JSON.stringify(event));
  const allowedTime = context.getRemainingTimeInMillis() - 2000;
  return Promise.resolve()
   .then(() => Promise.race([
    timeout(allowedTime), 
    eventAction(event, context)
   ]))
   .then(result => sendResult(event, result))
   .catch(e => sendError(event, e))
   .catch(e => {
    console.error('error sending status', e);
    return Promise.reject(errorToString(e));
   });
 };
};
```

The gotcha here is that CloudFormation won't automatically fail if there is an exception during the custom resource Lambda task, or if it times out. We need to handle all those types of errors internally and then report back. That's why the `processEvent` function first starts a `Promise` chain, so we can handle exceptions, asynchronous and synchronous errors easily. We also protect against the event action timing out, and leave the generic resource about two seconds to send the timeout response if needed.

## Utility functions

The final pieces are the three utility functions. 

The first one, `https-put.js`, will perform a `PUT` request with the headers expected by the pre-signed URL that CloudFormation provides. We could use some third-party module for network requests, such as `axios` or `got`, to provide network retries and content processing, but Node has all the features for a minimal implementation built in, and that does the trick for now. 

The key trick here for the CloudFormation flow, is to include the `content-length` and `content-type` headers for the upload. Leave the content type blank, and put the size of the payload into content length. If you don't do that, the pre-signed request upload will fail, and CloudFormation gets indefinitely stuck.

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

The second helper function provides error descriptions to CloudFormation. As CloudFormation expects a string, we need to consider synchronous exceptions, asynchronous promise rejections, plus strings or JavaScript error objects in all those cases. Here is a generic function that handles all those cases:

```js
// error-to-string.js
module.exports = function errorToString(error) {
 if (!error) {
  return 'Undefined error';
 }
 if (typeof error === 'string') {
  return error;
 }
 return error.stack || error.message || JSON.stringify(error);
};
```

The third function helps us act on a timeout as a Promise rejection, so we can notify CloudFormation in case of the task getting stuck.

```js
//timeout.js
module.exports = function timeout(duration) {
 return new Promise((resolve, reject) => {
  setTimeout(() => reject('timeout'), duration);
 });
};
```

## Wrapping up the configuration

With all those parts in place, we can now simply wire everything into a Lambda function:

```js 
// lambda.js
const pinpointEvent = require('./pinpoint-event'),
 resultToAppId = require('./result-to-app-id'),
 CloudFormationResource = require('./cloudformation-resource'),
 customResource = new CloudFormationResource(
  pinpointEvent, 
  resultToAppId
 );

exports.handler = customResource.processEvent;
```

Everything apart from the `pinpointEvent` and `resultToAppId` is generic, so you can reuse it for other types of CloudFormation custom resources.

Save all those files in a directory relative to the template, for example `code`, so we can use it in the template later.

## Recovering from development errors

Before we start deploying, there is one more trick, very useful when you're starting with new custom resources. Because CloudFormation templates can be very fiddly, it's useful to record calls to the custom resource lambda in case of unexpected errors. The generic flow in `cloudformation-resource.js` will protect you from timeouts and errors inside your task, but it won't be able to protect you against Lambda initialisation errors. 

CloudFormation uses the event-based Lambda invocation, which means that Lambda will re-try three times in case of unrecoverable errors, then give up. In such cases, CloudFormation never receives a response, so it will get stuck on your custom resource. Rolling back won't help as well, because it will just explode again. To recover, you'll need to know the pre-signed URL for responses and manually upload the result.

There are several good ways of logging Lambda invocations. One is to use [CloudTrail](https://aws.amazon.com/cloudtrail/). Another is to set up a SNS topic that sends you an e-mail in case of errors. In either case, once you know the pre-signed URL that CloudFormation expects, you can cook up a response in a JSON file, such as this:

```json
{
  "Status":"FAILED",
  "Reason":"Aborted"
  "StackId":"<COPY FROM THE REQUEST>",
  "RequestId":"<COPY FROM THE REQUEST>",
  "LogicalResourceId":"<COPY FROM THE REQUEST>",
  "PhysicalResourceId":"<COPY FROM THE REQUEST>",
}
```

Assuming you saved this to `body.json`, you can send it to CloudFormation using a PUT request from `curl`. Remember that the content type must be blank, otherwise the signature won't match.

```bash
curl -H "content-type: " -X PUT --data-binary @body.json <URL>
```



## Wiring everything up

I use SNS for dead letter queues as it is easy to turn on and off in the template itself. For this option, you'll need to set up a SNS topic and subscribe to it yourself -- check out the guide on [Receiving Email with Amazon SES](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/receiving-email.html) if you need help about that. We can now add another parameter `DLQSNSTopicARN` to the main pinpoint template, and a condition to check if it is defined:

```yml
AWSTemplateFormatVersion: '2010-09-09'
Description: Set up a Pinpoint application using CloudFormation 
Parameters:
  AppName: 
    Type: String
    Description: Pinpoint application name
  DLQSNSTopicARN: 
    Type: String
    Description: Dead-letter SNS topic for Lambda
    Default: ''

Conditions:
  IsDLQDefined: !Not [ !Equals ['', !Ref DLQSNSTopicARN]]

Resources: 
```

In the Lambda configuration, we can to load the JavaScript files and to delegate unrecoverable errors to the Dead Letter queue if defined:

```yml
PinpointConfigurationLambdaFunction:
  Type: 'AWS::Lambda::Function'
  Properties:
    Runtime: nodejs8.10
    Code: ./code 
    Handler: lambda.handler
    Role: !GetAtt PinpointConfigurationLambdaRole.Arn
    Timeout: 300
    DeadLetterConfig:
      !If
        - IsDLQDefined
        - TargetArn: !Ref DLQSNSTopicARN
        - !Ref AWS::NoValue
```

We can wire this function into the custom resource using the CloudFormation `GetAtt` function to extract the ARN:

```yml
PinpointApp:
  Type: 'Custom::PinpointApp'
  Properties:
    Name: !Ref AppName
    ServiceToken: !GetAtt PinpointConfigurationLambdaFunction.Arn
```

We also need an IAM role for the configuration function, that will allow it to log to CloudWatch, manage Pinpoint functions and optionally publish to the dead letter queue if it is set:

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
      - !If
        - IsDLQDefined
        - PolicyName: WriteDLQTopic
          PolicyDocument: 
            Version: '2012-10-17'
            Statement: 
              - Effect: Allow
                Action: 'sns:Publish'
                Resource: !Ref DLQSNSTopicARN
        - !Ref AWS::NoValue
```

Lastly, we can read the pinpoint application ID from the custom resource results, so we can use it in other CloudFormation resources:

```yml
Outputs:
  AppId:
    Value: !GetAtt PinpointApp.Id
```

## Trying it out

Instead of typing up individual parts of the files, get the complete code for this example from the [gojko/cloudformation-pinpoint](https://github.com/gojko/cloudformation-pinpoint) repository on Github. Then just package it as any other CloudFormation template (of course, replace the `<DEPLOYMENT_BUCKET_NAME>` with your deployment bucket):

```bash
aws cloudformation package 
  --template-file pinpoint-configuration.yml 
  --output-template-file output.yml 
  --s3-bucket <DEPLOYMENT_BUCKET_NAME>
```

This will create a deployable output template in `output.yml`. Deploy it from the CloudFormation web console, or from the command line, but make sure to include `CAPABILITIES_IAM` so CloudFormation can create the custom resource IAM role:

```bash
aws cloudformation deploy 
  --capabilities CAPABILITY_IAM 
  --template-file output.yml 
  --stack-name <STACK_NAME> 
  --parameter-overrides AppName=<NAME> DLQSNSTopicARN=<SNS_TOPIC_ARN>
```

If you do not want to use a SNS topic for dead letters, then just omit the last parameter section.

## Key things to remember

* Custom resources allow you to invoke your own lambda function as part of the CloudFormation deployment process
* Log the Lambda requests using CloudTrail or SNS so you can recover from initialisation errors while developing
* Return the physical resource ID consistently -- either use the ID of the actual resource if you create something, or create something reasonably unique for transient requests and then reuse the same value for updates and deletes
* Make sure to send an empty content type header and the actual payload size in the content length header when uploading results to CloudFormation, otherwise the pre-signed upload will fail
* Give the Lambda function enough time to handle creation errors and timeouts from your task, and upload the result in those cases. Even though CloudFormation invokes your Lambda function, it won't immediately recognise unrecoverable errors.



