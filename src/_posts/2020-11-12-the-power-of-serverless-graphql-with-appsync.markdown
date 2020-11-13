---
layout: post
title:  "The Power of Serverless GraphQL with AWS AppSync"
excerpt: "A serverless application for handling webhooks using EventBridge event bus, API Gateway's HTTP API and Lambda function"
date: 2020-11-12 11:00:00 +0200
categories: Serverless
author_name : Slobodan Stojanović
author_url : /author/slobodan
author_avatar: slobodan.jpg
twitter_username: slobodan_
show_avatar: true
read_time: 20
feature_image: the-power-of-serverless-graphql/preview.png
show_related_posts: false
square_related: recommend-slobodan
---

Every story needs a hero. But, not all heroes are the same. Some of them have superpowers, and some are ordinary people. This story's hero is just a regular software developer who works in a small team on a medium-size application. Our hero loves his job most of the time, except when he sends a test push notification to thousands of their customers in production, like a few minutes ago.

![](/img/the-power-of-serverless-graphql/01-push-notifications.png)

One day, his boss came with a new project. "We need to build a new complex application for our new important customer." Nice, our hero loves challenges! "But we need to do it fast, as we have a short deadline because they have an important marketing event!" Ok, how fast do we need to build an app? "It needs to be ready for yesterday. And it needs to be real-time and scalable!"

The new project is a big challenge for our hero, as he never did that kind of project. Can he even do it?

"You can do it," his boss says. "I also hired a famous consultant to help you." That's awesome! Challenge accepted.

After a full-day meeting with the consultant, and a whiteboard full of weird diagrams, the plan was simple: "Just use Kubernetes!"

![](/img/the-power-of-serverless-graphql/02-consultant.png)

But our hero doesn't know Kubernetes. And there's no time to learn it now. What should he do?

He started wondering if he is the only one who doesn't know Kubernetes. Is he good enough for this job?

Our hero spent a sleepless night in front of his computer with his faithful sidekick, a rubber duck. He tried to learn as much as he can about this new technology. But he ended up more confused and tired.

![](/img/the-power-of-serverless-graphql/03-sidekick.png)

## You should try Serverless GraphQL

In the middle of the night, our hero's faithful sidekick said, "you should try serverless GraphQL."

![](/img/the-power-of-serverless-graphql/04-try-serverless-graphql.png)

Was he dreaming? And what the heck is serverless GraphQL? He knows what serverless is, but what's GraphQL?

### What's GraphQL

Do you remember when Mark Zuckerberg [said](https://techcrunch.com/2012/09/11/mark-zuckerberg-our-biggest-mistake-with-mobile-was-betting-too-much-on-html5/), "our biggest mistake was betting too much on HTML5?" It was a long time ago, back in 2012, when HTML5 was in its early days.

At that moment, the Facebook mobile app was an HTML5 web app embedded in the native mobile shell. They served all the news feed updates as HTML data from the server. However, HTML5 was in its early days, and the mobile web views were not performant enough, so the app wasn't stable and scalable enough.

![](/img/the-power-of-serverless-graphql/05-fb-mobile-app.png)

In 2012, Facebook's engineering team started rebuilding their mobile and switching to the native iOS and Android apps. They evaluated different options for delivering the news feed data, including RESTful services  and Facebook Query Language (FQL).

In the ["GraphQL: A data query language"](https://engineering.fb.com/2015/09/14/core-data/graphql-a-data-query-language/) article in 2015, Lee Byron wrote:

> We were frustrated with the differences between the data we wanted to use in our apps and the server queries they required. We don’t think of data in terms of resource URLs, secondary keys, or join tables; we think about it in terms of a graph of objects and the models we ultimately use in our apps like NSObjects or JSON.

This frustration led the Facebook engineering team to rethink the way they serve data to their mobile application. Instead of returning a full model with a lot of unnecessary data, they tried to develop a new system to return only the data the application needed.

![](/img/the-power-of-serverless-graphql/06-data.png)

In 2015, they [announced](https://engineering.fb.com/2015/09/14/core-data/graphql-a-data-query-language/) GraphQL, an open-source data query language. The idea behind GraphQL was simple, the client defines the data structure, and the server provides a JSON response with precisely the same format.

For example, the client wants to get the user with a specified ID. However, the application needs only the user's name, a profile photo with a specific size, and the first five friend connections. Instead of sending two or three different requests to the RESTful API, with GraphQL, you can send a request similar to the one in the image below. And the response will be the JSON with the same structure, as you can see on the right side of the same image.

![](/img/the-power-of-serverless-graphql/07-an-example.jpg)

That sounds nice and smart. But why should our hero care about GraphQL? He doesn't have the same problem Facebook had.

The problem Facebook's engineering team had was the leading cause for inventing GraphQL. However, that's not the only problem GraphQL solves. If you have one of the following symptoms, GraphQL might be the cure for the problems your application faces, too:

- Distinct front end clients for multiple platforms, such as web and mobile, have different data requirements.
- Your back end serves data to your client apps from different sources. For example, your app has SQL and NoSQL databases, and it connects to some external systems.
- Your app has a complex state and caching managements for both front end and back end.
- Slow pages, especially on mobile, caused by multiple dependant HTTP requests.

This list is not complete, and GraphQL can bring even more benefits to your application. Some of the main characteristics of GraphQL are:

- It defines a data shape. The request always specifies the response's form, which makes requests more predictable and easier to use.
- It's hierarchical. Its strict relation between objects with graph-structured data simplifies getting data from multiple sources.
- It's strongly typed. It can give you descriptive error messages before you run a query.
- It's a protocol, not storage. Each GraphQL field is backed by a function on the back end, which allows you to connect it to any storage you want in the background.
- It's introspective. You can query the GraphQL server for the types it supports. This gives you built-in documentation and also a base for a powerful toolset.
- It's version free. The shape of the data is always defined by the client's request, which means adding additional fields to your model will not affect your client application until you change the query itself.

To combine data from multiple sources using RESTful API, you often send multiple HTTP requests and then connect data on the client-side. This works fine in perfect conditions. However, users don't always use your app in ideal conditions. They are often on mobile with a limited or unstable network. Or they live in Australia, and each request is a few hundred milliseconds slower.

![](/img/the-power-of-serverless-graphql/08-multiple-data-sources.gif)

With GraphQL, you can archive the same with a single request. This will push a bit more load to the server-side, but that works just fine in most cases. It's even better when you don't own the server.

![](/img/the-power-of-serverless-graphql/09-graphql-request.gif)

### Where to start with GraphQL

With GraphQL, you start by shaping your data using types. For example, if you are building a blog, you will have an author and a post, similar to the following code snippet. Each post will have its id, a name, a title, and an author. Authors have their ids, names, and a list of their posts.

As you can see, types also define a relation between an author and posts.

```graphql
type Author {
  id: Int
  name: String
  posts: [Post]
}

type Post {
  id: Int
  title: String
  text: String
  author: Author
}
```

Once you have types, you can build your GraphQL schema. In the code snippet below, we define two queries: get author by ID and get posts by title. Each of these queries defines input parameters with their types and a return type.

```graphql
type Query {
  getAuthor(id: Int): Author
  getPostsByTitle(titleContains: String): [Post]
}

schema {
  query: Query
}
```

As GraphQL is not storage but a protocol, we need to tell GraphQL where and how it can read the data by creating resolvers. In the following code snippet, we define two resolvers: one for the author that connects to the SQL database and one for a list of posts sends an HTTP request to the blog platform API.

```
getAuthor(_, args){
  return sql.raw('SELECT * FROM authors WHERE id = %s', args.id);
}

posts(author){
  return request(`https://api.blog.io/by_author/${author.id}`);
}
```

Finally, we can run the query. As we defined queries, we can ask for an author by their ID. Relations allow us to get a list of all author's posts in the same request. And if we ask for the author's name for each blog post, that name will be the same as the author's name above because it points to the same author.

```graphql
{
  getAuthor(id: 5){
    name
    posts {
      title
      author {
        # this will be the same as the name above
        name
      }
    }
  }
}
```

Once we run the query, GraphQL will parse the request, then validate the types and data shape, and finally, if the first two steps are correct, it will run the query and our resolvers. Once we receive the data, it'll look similar to the following JSON data:

```json
{
  "name": "Slobodan",
  "posts": [{
    "title": "The power of serverless GraphQL with AppSync",
    "author": {
      "name": "Slobodan"
    }
  }, {
    "title": "Handling webhooks with EventBridge, SAM and SAR",
    "author": {
      "name": "Slobodan"
    }
  }]
}
```

By GraphQL specification, queries read the data. GraphQL specification also defines mutations and subscriptions. Mutations modify the existing data (i.e., add a new author or edit post), and subscriptions can notify you whenever the data is changed (i.e., it'll run whenever the post is published).

### Why do we need serverless GraphQL?

"You can always deploy your GraphQL using Kubernetes and write your resolvers by hand," the rubber duck said, "but there's an easier way."

GraphQL makes retrieving your data from the client-side effortless, but you still need to manage and scale your infrastructure. And now, you have one central place that controls all of your requests. Unless you do the same you do with the other web applications -- make your application serverless. Serverless GraphQL brings the best of both worlds: GraphQL makes you client-to-server connection effortless, and serverless simplifies maintenance of your infrastructure.

![](/img/the-power-of-serverless-graphql/10-scaling.png)

"Interesting, but how do I make GraphQL application serverless?"

"There are many ways to do that," the rubber duck said. "You can do that manually using the familiar serverless services. For example, on AWS, you can use Amazon API Gateway and AWS Lambda."

![](/img/the-power-of-serverless-graphql/11-manually.png)

"Or you can use AWS AppSync." Wait, what's AppSync?

### AWS AppSync

[AWS AppSync](https://aws.amazon.com/appsync/) is a managed service that uses GraphQL to make it easy for applications to get exactly the data they need. AppSync helps you to develop your application faster.

To build your app using AppSync and GraphQL, you'll need to do the following:

1. Define GraphQL schema.

2. Automatically provision a DynamoDB data source and connect resolvers.

3. Write GraphQL queries and mutations.

4. Connect your front end app to the GraphQL server.

"Let's give it a try," the rubber duck said. "You can start with the guided schema wizard on the AWS Web Console, but you should use [AWS Amplify](https://docs.amplify.aws), [AWS CloudFormation](https://aws.amazon.com/cloudformation/), or [AWS Cloud Development Kit (CDK)](https://aws.amazon.com/cdk/) for more complex apps."

After a few hours of playing with the AWS Amplify CLI, our hero managed to build a simple app. AWS Amplify CLI helped him to get started with the following three simple commands:

```bash
amplify init
amplify add api
amplify push
```

"Wow, that was fast!" our hero said.

A week or so later, he created a working prototype of the application. "We should show this to consultant!"

## The power of AppSync

"That will never work!" the consultant said, "this Amplify is not good enough for our complex project."

AWS Amplify is very good, and it's especially useful for front-end heavy web applications. However, if you have a complex back end, it's probably better to start with AWS CloudFormation or AWS CDK. Alternatively, you can begin with Amplify and then migrate to CloudFormation or CDK because Amplify generates CloudFormation files under the hood for you.

AWS AppSync works fine with CDK and CloudFormation. Here's a simple CDK example using TypeScript:

```typescript
import * as cdk from '@aws-cdk/core';
import * as appsync from '@aws-cdk/aws-appsync';

export class AppsyncCdkAppStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // Creates the AppSync API
    const api = new appsync.GraphqlApi(this, 'Api', {
      name: 'my-awesome-app',
      schema: appsync.Schema.fromAsset('graphql/schema.graphql'),
    });

    // Prints out the AppSync GraphQL endpoint to the terminal
    new cdk.CfnOutput(this, "GraphQLAPIURL", {
     value: api.graphqlUrl
    });
  }
}
```

"Ok, that might work for us." said the consultant, "but our app needs to be real-time."

Remember GraphQL subscriptions? AWS AppSync supports them [out-of-the-box](https://docs.aws.amazon.com/appsync/latest/devguide/aws-appsync-real-time-data.html). It lets you specify which part of your data should be available in a real-time manner. To activate the real-time subscriptions, you can add something similar to the following code snippet to your GraphQL schema. This code snippet will allow you to get real-time notifications whenever "addPost," "updatePost," or "deletePost" mutation is triggered.

```
type Subscription {
  addedPost: Post
  @aws_subscribe(mutations: ["addPost"])
  updatedPost: Post
  @aws_subscribe(mutations: ["updatePost"])
  deletedPost: Post
  @aws_subscribe(mutations: ["deletePost"])
}
```

"Nice, but it also needs to be scalable!" the consultant reminded our hero.

AppSync is serverless, and it connects to familiar serverless services under the hood, such as Amazon DynamoDB. Real-time subscriptions are scalable, too. What does it mean to be scalable? According to [this article](https://aws.amazon.com/blogs/mobile/appsync-realtime/), the AppSync GraphQL Subscriptions were load-tested with more than ten million parallel connections! And you do not need to do anything to enable that. Everything is already set up for you. Impressive, right?

![](/img/the-power-of-serverless-graphql/12-realtime-demo.png)

"That's impressive! But we also need search functionality? As far as I know, DynamoDB is not ideal for the search. Can AppSync do something for that?"

AppSync has [direct integration](https://docs.aws.amazon.com/appsync/latest/devguide/tutorial-elasticsearch-resolvers.html) with Amazon ElasticSearch Service! Not sure if there's an acronym for that one. You can do operations such as simple lookups, complex queries & mappings, full-text searches, fuzzy/keyword searches, or geo lookups directly from your GraphQL. AWS Amplify will handle this for you out-of-the-box, and if you use AWS CloudFormation or CDK, you'll need to create your Amazon ElsasticSearch Service instance and send data to it.

"Ok," the consultant said, "but we also need to connect to an existing service. Can your AppSync do that?"

You can connect AWS AppSync to AWS Lambda! AWS AppSync lets you [use AWS Lambda](https://docs.aws.amazon.com/appsync/latest/devguide/tutorial-lambda-resolvers.html) to resolve any GraphQL field, which allows you to query or send mutations to any storage engine or a third-party service.

"What about roles and permissions? Do we need to use Lambda resolvers to add access control?"

AppSync has the following [four built-in authorization mechanisms](https://docs.aws.amazon.com/appsync/latest/devguide/security.html):

- API_KEY authorization lets you specify API keys, hardcoded values, that the client needs to send with their GraphQL requests. API keys are especially useful for controlling throttling.
- AWS_IAM authorization lets you associate [Identity and Access Management](https://aws.amazon.com/iam/) (IAM) access policies with your GraphQL endpoint.
- OPENID_CONNECT authorization enforces [OpenID Connect](https://openid.net/specs/openid-connect-core-1_0.html) (OIDC) tokens provided by an OIDC-compliant service. It allows you to use the third-party OIDC service to authorize your users.
- AMAZON_COGNITO_USER_POOLS authorization enforces OIDC tokens provided by [Amazon Cognito User Pools](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-identity-pools.html). A user pool is your user directory in [Amazon Cognito](https://aws.amazon.com/cognito/).

"I am a bit confused," the consultant said. "Can you use this for our multi-tenant application?"

You can use [Cognito Groups](https://aws.amazon.com/blogs/aws/new-amazon-cognito-groups-and-fine-grained-role-based-access-control-2/). Each group represents different user types and app usage permissions. With AppSync, you can customize each groups' permissions for every query or mutation. For example, if you are building a blog platform, you can add your users to the "Bloggers" and "Readers" groups, and then allow "Readers" to read posts and "Bloggers" to add or edit posts.

```
type Query {
   posts:[Post!]!
   @aws_auth(cognito_groups: ["Bloggers", "Readers"])
}

type Mutation {
   addPost(id:ID!, title:String!):Post!
   @aws_auth(cognito_groups: ["Bloggers"])
}
```

"If you need more flexibility that Cognito Groups can offer," the rubber duck said, "you can use Resolver Mapping Templates and VTL."

![](/img/the-power-of-serverless-graphql/13-resolving-mapping-template.png)

"What, your rubber duck talks?" the consultant said, but he was quickly distracted by the weirdest thing he saw in a long time. "What's VTL template?" the consultant and our hero asked at the same time.

Resolvers connect GraphQL and a data source. AppSync lets you use VTL to write a Resolver Mapping Template and tell GraphQL how to connect to the DynamoDB and ElasticSearch Service.

[Apache Velocity Template Language](https://velocity.apache.org/engine/1.7/user-guide.html) (VTL) is a Java-based alien language. Pardon, its Java-based templating engine. VTL allows you to write request and response Resolver Mapping Templates. You can embed these templates in your CloudFormation template or put them in your Amazon S3 bucket. Whatever you do, VTL templates will be hard to test in isolation. However, they are useful. Here's the example of the VTL template that allows the owner only to do the selected action:

```
#if($context.result["Owner"] == $context.identity.username)
    $utils.toJson($context.result)
#else
    $utils.unauthorized()
#end
```

"Ok, but you mentioned testing," the consultant said. "So, how do you test your VTL templates?"

Testing VTL templates is not easy. The more business logic you have in your VTL templates, the more you need end-to-end tests. With end-to-end tests, you'll be sure that your application works correctly. However, these tests are slow and expensive. Having unit tests would speed up your development a lot, mainly because you need to deploy your application to check if your template is valid. Using few minutes long CloudFormation deployments as a VTL template linting tool is far from practical.

As VTL templates are Java-based templates invented many years ago, you can use the Apache Velocity Template Engine to test your templates in isolation. However, AppSync VTL has a lot of utility functions that you would need to mock.

Fortunately, there's a better way to test your VTL templates in isolation. With AWS Amplify CLI open-source modules, your tests can look similar to the following code snippet.

```typescript
import { AppSyncMockFile } from 'amplify-appsync-simulator'
import { VelocityTemplate } from 'amplify-appsync-simulator/lib/velocity'
import { readFileSync } from 'fs'
import { join } from 'path'
import { getAppSyncSimulator } from './helpers/get-appsync-simulator'
import { getVelocityRendererParams } from './helpers/get-velocity-renderer-params'

// Read the VTL file from the disc
const vtl = readFileSync(join(__dirname, '..', 'get-company-resolver-request.vtl'), 'utf8')
const template: AppSyncMockFile = { content: vtl }

// Create a simulator instance
const simulator = getAppSyncSimulator()

// Create a VelocityTemplate instance
const velocity = new VelocityTemplate(template, simulator)

describe('some-file.vtl', () => {
	// Render the VTL template and provide your context
  const { ctxValues, requestContext, info } = getVelocityRendererParams('username', {
    'custom:companyId': 'company',
  })

  // Test if the VTL template response returns the expected result
  test('should render a template', () => {
    const result = velocity.render(ctxValues, requestContext, info)
    expect(result).toEqual({
      errors: [],
      isReturn: false,
      stash: {},
      result: {
        version: '2018-05-29',
        operation: 'GetItem',
        key: {
          id: { S: 'company' },
        },
      },
    })
  })
})
```

The code snippet above uses Jest, a popular JavaScript testing tool, but you can use your favorite JavaScript framework.

Testing AppSync apps is a complex topic that deserves a dedicated article. Be patient; it's on its way. Or even better, subscribe to [the mailing list](https://slobodan.me/subscribe) and get notified when we publish that article.

"I don't like these VTL templates," the consultant said. "Me neither," our hero agreed.

You can use [Direct Lambda Resolvers](https://docs.aws.amazon.com/appsync/latest/devguide/direct-lambda-reference.html) and skip VTL entirely. AppSync sends [the Context object](https://docs.aws.amazon.com/appsync/latest/devguide/resolver-context-reference.html) directly to your Lambda function.

"Ok, that's better," says the consultant, "is there a way to reuse some parts of the business logic?"

If you use Direct Lambda Resolvers, you can share the logic between multiple Lambda functions the same way you do in any Lambda function. The other option that also works with VTL templates is using [Pipeline Resolvers](https://docs.aws.amazon.com/appsync/latest/devguide/pipeline-resolvers.html). A pipeline resolver allows you to compose operations and run them in sequence.

A pipeline resolver contains a "Before" mapping template, an "After" mapping template, and a series of operations (called Functions). An operation can be a VTL template connected to some data source, such as a DynamoDB table, or a Lambda function if you use Direct Lambda Resolvers.

"I bet this is too complex for the front end!"

Remember AWS Amplify? It has a collection of [excellent front end libraries](https://docs.amplify.aws) for vanilla JavaScript and all the popular front end frameworks, such as React, Angular, and Vue. It also has libraries for native iOS and Android mobile apps!

"Fine, but I think we decided not to use AWS Amplify for our app. Why are you mentioning Amplify front end libraries now?"

You can use AppSync with CloudFormation or CDK and use the AWS Amplify front end libraries! They work great together.

Amplify can also automatically generate queries, mutations, subscriptions, and TypeScript types for us and help our front end team.

Amplify also supports offline data synchronization with its [Amplify DataStore](https://docs.amplify.aws/lib/datastore/getting-started/q/platform/js), which gives you even more power on the front end. And AppSync supports caching, which can make our front end applications faster.

"All these things sound great," the consultant says, "but I guess you need to deploy the app to the AWS whenever you want to test it. That will slow us down, right?"

Amplify lets you mock GraphQL APIs, including resolver mapping templates with the DynamoDB storage.

"Ok, fine. But our app architecture is a bit more complex. What if we need event sourcing, CQRS, or some other slightly more complex architecture?"

You can use GraphQL with event sourcing and CQRS. AppSync will help you with its integration with other AWS services, such as DynamoDB and AWS Lambda.

For example, [Vacation Tracker](https://vacationtracker.io) uses AppSync the following way:

- The client (React application) sends commands (mutations) to the AppSync.
- All events are stored in the DynamoDB table.
- The DynamoDB table sends the stream to the Lambda function that publishes them to the EventBridge. EventBridge [now supports replays](https://aws.amazon.com/blogs/aws/new-archive-and-replay-events-with-amazon-eventbridge/), which allows Vacation Tracker to replay a group of events.
- EventBridge events trigger a series of Lambda functions that apply some business logic.
- AppSync subscription events tell the front end that the business logic is applied and if the event was successful or failed. The business logic also creates a new read-optimized snapshot.
- The client use GraphQL queries to query the data from one of the read-optimized DynamoDB tables.

![](/img/the-power-of-serverless-graphql/14-es.gif)

"Ok, I give up!" the consultant said. "Let's use GraphQL and AWS AppSync!"

![](/img/the-power-of-serverless-graphql/15-done.png)

## And they lived happily ever after

Our story hero became the project hero. He delivered the project within the deadline and made his boss and customers happy.

But what about you? Why would you use GraphQL and AppSync?

- GraphQL makes your frontend and backend connection effortless.
- AppSync makes GraphQL management effortless.
- Serverless GraphQL makes you a superhero.

----

If you want to learn more about serverless GraphQL with AppSync or testing serverless applications, you might want to join my [mailing list](https://slobodan.me/subscribe) and catch the new articles and free courses that we are working on.