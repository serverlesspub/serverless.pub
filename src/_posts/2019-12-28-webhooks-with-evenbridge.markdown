---
layout: post
title:  "Handling webhooks with EventBridge, SAM and SAR"
excerpt: "Semantic versioning, region replication and account permissions for Lambda layers"
date: 2019-12-28 12:00:00 +0200
categories: Serverless
author_name : Slobodan Stojanović
author_url : /author/slobodan
author_avatar: slobodan.jpg
twitter_username: slobodan_
show_avatar: true
read_time: 11
feature_image: webhooks-with-eventbridge/serverless-webhook-integration.png
show_related_posts: false
square_related: recommend-slobodan
---

Applications I worked on in the last decade were rarely isolated from the rest of the world. Most of the time, they had many interactions with other applications out there. From time to time, some of these integrations are using WebSockets, which makes our integration realtime. But much more common integration is using webhooks to send us new changes, and give us some API or SDK to allow us to communicate in the other direction. There's a big chance that you worked with many similar integrations, such as Stripe, Slack, Github, and many others. A typical integration looks similar to the diagram below.

![A typical webhook integration](/img/webhooks-with-eventbridge/common-webhook-integration.png)

## A quest to a cleanest webhook integration

In [Vacation Tracker](https://vacationtracker.io/?utm_source=serverless.pub), the leave tracking application I am working on, we have a lot of external integrations. We integrate with Slack for user management, and we use Slack chatbot as one of the entry points to our app, and we are expanding to other platforms. We outsourced payments to Stripe, emails to MailChimp and Customer.io, and so forth. Many of these integrations require webhook integration, and from the very beginning, we are on a quest to the clean and simple way to manage our webhooks.

From its early days, [Serverless Application Repository](https://aws.amazon.com/serverless/serverlessrepo/) (SAR) sounds like an excellent tool for isolation of the common patterns in our serverless applications. If we do a similar payment integration to multiple applications, why don't we move that set of functions and services to a place that allows us to reuse it quickly, both privately and publicly?

Our initial idea was to put all of our integrations as separate SAR apps, open-source some of them, and keep the rest of them privately. Something similar to the following diagram.

![Initial idea: Each integration goes to its own SAR app](/img/webhooks-with-eventbridge/idea-1.png)

Not a bad for an initial idea, but we quickly realized that there is a common thing in a lot of our potential apps. As you can guess: a webhook.

What's an easy way to handle a webhook in a serverless application? We need some API; we can start with an API Gateway. And we need some integration point with the rest of our business logic. One of the logical picks would be [Amazon Simple Notification Service](https://aws.amazon.com/sns/) (SNS). And we need a Lambda in between.

Wait, do we need that Lambda function?

It seems that we do not need it, because API Gateway can talk directly to multiple services, including SNS, using [a service integration](https://www.alexdebrie.com/posts/aws-api-gateway-service-proxy/). You need to write a "simple" template using the [Velocity Template Language](https://velocity.apache.org/engine/1.7/vtl-reference.html) (VTL).

What's VTL? I would say it's an alien language (well, its Java-based 🤷‍♂️) insanely hard to test in isolation in a serverless application, especially in [AWS CloudForamation](https://aws.amazon.com/cloudformation/) and [AWS Serverless Application Model](https://aws.amazon.com/serverless/sam/) (SAM) templates.

Our webhook would look similar to the following diagram.

![Idea #2: A direct API Gateway integration to an SNS topic](/img/webhooks-with-eventbridge/idea-2.png)

API Gateway gives us a REST API, with a lot of awesome integrations and tricks. However, an API required for a common webhook is quite simple. We can use [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) instead, but that requires a few more modifications of our app, and time spent on these modifications is time we wasted for working on our business logic.

Fortunately, AWS announced a new API Gateway service on re:Invent 2019 conference, called [HTTP APIs for API Gateway](https://aws.amazon.com/blogs/compute/announcing-http-apis-for-amazon-api-gateway/). HTTP APIs are a lighter, cheaper and slightly faster version of API Gateway's REST APIs. HTTP APIs don't support VTL templates and service integrations at the moment, and we need our Lambda function back. At least until AWS implements service integrations, or add [Lambda Destinations for synchronous invocations](https://github.com/stojanovic/random/issues/1). Back to the drawing board! Our SAR app should look similar to the following diagram.

![Idea #3: API Gateway's HTTP API to a Lambda Functio, and then to an SNS topic](/img/webhooks-with-eventbridge/idea-3.png)

The new architecture looks good. But after integrating many webhooks, we'll end up with a lot of SNS topics. SNS topics are serverless, we pay for used capacity only, but each of them come with a custom event structure, which makes documenting and integrating all event schemas harder down the road.

It would be great if AWS had an event bus that would make this easier, right?

Meet [Amazon EventBridge](https://aws.amazon.com/eventbridge/), a serverless event bus that connects application data from your apps, SaaS, and AWS services. Yes, something like an enterprise service bus.

### Why EventBridge instead of SNS

Events are the core of the common serverless application. We use events to trigger our functions; we send them to queues and notification services, we stream them. But events are also the core of almost any application.

Let's take Vacation Tracker as an example. When you request a leave or a vacation in your company, that's an event that requires some action. Response to your request is another event. When your leave starts, that's an event, too.

EventBridge represents a new home for your events. We can use it to integrate with some of the third-party services or build our integrations.

Here are a few reasons why we would pick EventBridge instead of SNS:

- We can connect Amazon SNS with a few other services directly. At the moment, EventBridge supports 20 different targets, including Lambda functions, SQS, SNS, Kinesis and others.
- It gives us a single place to see and handle all of our event subscriptions.
- For unsuccessful deliveries, SNS retries up to three times. EventBridge does retries out of the box for 24 hours. Both SNS and EventBridge support [Lambda Destinations](https://aws.amazon.com/blogs/compute/introducing-aws-lambda-destinations/).
- EventBridge has [Schema Registry](https://aws.amazon.com/about-aws/whats-new/2019/12/introducing-amazon-eventbridge-schema-registry-now-in-preview/) for events. It supports versioning, and it has an auto-discovery and can generate code bindings.

Enough to give it a chance.

### The solution

Our SAR app should look similar to the one we already have, with one crucial difference: we don't want to create an EventBridge event bus in the SAR app. We'll use the same event bus for multiple events, so it's better to keep it outside of the SAR app and pass the reference to it to the SAR app.

As you can see in the following diagram, we'll have the API Gateway's HTTP API and a Lambda function in our SAR app. That app receives webhook events from any external source and passes it to our event bus. We'll route the events from our event bus to functions or other services.

![A serverless webhook integration using EventBridge](/img/webhooks-with-eventbridge/serverless-webhook-integration.png)

Let's implement it.

### EventBridge integration with AWS SAM

We are using AWS SAM for our serverless apps. Until SAM documentation gets some support from [Amazon Kendra](https://aws.amazon.com/kendra/), searching for EventBridge support can take some time.

After a few minutes of digging through the documentation and Github issues and pull requests, we can see that SAM doesn't have support for EventBridge out of the box. Fortunately, CloudFormation [got support](https://aws.amazon.com/about-aws/whats-new/2019/10/amazon-eventbridge-supports-aws-cloudformation/) for EventBridge resources a few months ago.

CloudFormation has support for the following EventBridge resource types:

- The `AWS::Events::EventBus` resource creates or updates a custom or partner event bus.
- The `AWS::Events::EventBusPolicy` resource creates an event bus policy for Amazon EventBridge, that enables your account to receive events from other AWS accounts.
- The `AWS::Events::Rule` resource creates a rule that matches incoming events and routes them to one or more targets for processing.

We'll need `AWS::Events::EventBus` to create a new event bus for our app.

But before we add an event bus, make sure that you have AWS SAM installed, and then run the `sam init -n stripe-webhook -r nodejs12.x --app-template hello-world` command from your terminal to create a new SAM app. This command creates the "stripe-webhook" folder with the "template.yaml" file and the "hello-world" function.

Open the "template.yaml" file in your favorite code editor, and add the following resource at the top of the Resources section:

```yaml
PaymentEventBus: 
  Type: AWS::Events::EventBus
  Properties: 
    Name: paymentEventBus
```

The resource above creates an EventBridge event bus named "paymentEventBus". Besides the "Name" property, the `AWS::Events::EventBus` accepts the "EventSourceName" property, required when we are creating a partner event bus. Since we are creating a custom event bus, we do not need it.

Then we want to add a subscription for our event bus to the Lambda function. We can do that using the CloudFormation `AWS::Events::Rule` resource, however, the more natural way is using the SAM's CloudWatchEvent event. To add a subscription, replace the "HelloWorld" resource with the following one:

```yaml
ChargeHandlerFunction:
  Type: AWS::Serverless::Function
  Properties:
    CodeUri: hello-world/
    Handler: app.lambdaHandler
    Runtime: nodejs12.x
    Events:
      OnChargeSucceeded:
        Type: CloudWatchEvent
        Properties:
          EventBusName: paymentEventBus
          Pattern:
            detail:
              body:
                type:
                - charge.succeeded
```

This resource triggers our HelloWorld function when our event bus receives the "charge.succeeded" event from a Stripe webhook, or any other event that contains the following:

```json
{
  "body": {
    "type": "charge.succeeded"
  }
}
```

The powerful thing about EventBridge is that we can easily subscribe to all events that contain a specific pattern in the request body or headers. For example, to subscribe to both "charge.succeeded" and "invoice.upcoming" events, modify the subscription pattern to look like the following one:

```yaml
Pattern:
  detail:
    body:
      type:
      - charge.succeeded
      - invoice.upcoming
```

As we don't use an API Gateway anymore, we need to update the HelloWorld function to log the event. To do so, open the "hello-world/app.js" file in your code editor, and replace its content with the following code snippet:

```javascript
exports.lambdaHandler = async (event) => {
  console.log('RECEIVED EVENT', JSON.stringify(event));
  return true;
};
```

We also want to add our webhook endpoint SAR application. To do so, add the following resource to the Resources section of the "template.yaml" file:

```yaml
StripeWebhook:
  Type: AWS::Serverless::Application
  Properties:
    Location:
      ApplicationId: arn:aws:serverlessrepo:us-east-1:721177882564:applications~generic-webhook-to-eventbridge
      SemanticVersion: 1.0.0
    Parameters:
      EventBusName: paymentEventBus
      EventSource: stripe-webhook
```

Before deploying the application, we need to modify the output to print the webhook URL. To do so, replace  the Outputs section of the "template.yaml" file with the following:

```yaml
Outputs:
  WebhookUrl:
    Description: "The URL of the Stripe webhook"
    Value: !GetAtt StripeWebhook.Outputs.WebhookApiUrl
```

To deploy the application, open your terminal, navigate to the project folder, and run the `sam deploy --guided` command to deploy the application. Once you follow the instructions, SAM deploys your app, and prints the webhook URL in the output.

### Testing the webhook

To test this webhook, you can navigate to your Stripe dashboard, switch it to the test mode, then click on the "Developers" link in the sidebar, and select the "Webhooks" from the sub-menu. Click the "Add endpoint" button. Paste the webhook URL you copied from the sam deploy output in the "Endpoint URL" field, and select the "charge.succeeded" event from the "Events to send" dropdown. Finally, click the "Add endpoint" button to add a new webhook, and the "Send test webhook" button to test your webhook.

You can confirm that your event was successfully received by listing the CloudWatch logs for the "ChargeHandlerFunction" function. To do so, navigate to the CloudWatch logs in the AWS Web Console, or use the `sam logs` command.

If you do not have the Stripe account, you can send the POST request to the webhook URL using CURL or Postman. Just make sure you send the `Content-Type: application/json` header and the body similar to the following code snippet:

```json
{
  "body": {
    "type": "charge.succeeded"
  }
}
```

### SAR application

As you can see in the [Github repository](https://github.com/vacationtracker/generic-webhook-to-eventbridge), our SAR app is simple. It receives the event bus name through the parameters, defines a Lambda function and an API Gateway's HTTP API, and outputs the webhook URL.

To be able to send events to the event bus, the Lambda function requires the following policy:

```yaml
Policies:
  -
    Version: 2012-10-17
    Statement:
      -
        Effect: Allow
        Action:
          - events:PutEvents
        Resource: '*'
```

This policy allows our function to send the events to the EventBridge event buses. This policy does not allow us to add the "events:PutEvents" action to a specific EventBus, so we need to pass `'*'` as a Resource value.

To send an event, we use the ["PutEvents"](https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/EventBridge.html#putEvents-property) property from the EventBridge class of the AWS SDK for JavaScript.

## That's all folks

EventBridge promises an easy but powerful way to organize both internal and external events in our serverless applications. In combination with SAR, we can create reusable parts of the application and potentially save much time.

However, EventBridge is not a silver bullet. By using it and its Schema Registry, we give all of our event structure to Amazon. With its current velocity, Amazon can sooner or later come after any of our businesses, and the Schema Registry could make that easier. Fortunately, EventBridge upsides and promises are way higher than those risks. Also, avoiding the particular service or choosing another cloud vendor doesn't help you a lot anyway.

There are a few other downsides of the EventBridge at the moment. The main one is the debugging, but I am sure AWS will improve that significantly in the coming months.

Build something awesome using the EventBrigde, and let us know once you do it! Just make sure you check the service limits (which are quite high) before you lock you in a solution not made for your problem.