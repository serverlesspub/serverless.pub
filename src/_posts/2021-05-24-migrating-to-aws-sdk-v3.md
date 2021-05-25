---
layout: post
title:  "Migrating to AWS SDK v3 for Javascript"
excerpt: "tips, gotchas and surprises with the new AWS SDK"
date: 2021-05-25 01:00:00 +0000
categories: 
  - Serverless
author_name : Gojko Adzic
author_url : /author/gojko
author_avatar: gojko.jpg
twitter_username: gojkoadzic
show_avatar: true
feature_image: change-seo.jpg 
show_related_posts: false
square_related: recommend-gojko
---

AWS SDK for JavaScript is going through a major update, with version 3 becoming ready for production usage. The API is not backwards compatible with the old version, so migrating requires a significant change in client code. Some of it is for the better, some not so much. We've recently migrated a large project from v2 to v3. In this article, I'll go through the key points for migration, including the things that surprised us, including the stuff that required quite a lot of digging.

## Why v3?

The key advantage of v3 over v2 is modular design. Instead of a huge package that contains clients and metadata for all AWS services, with V3 you can include just the stuff you really need, which leads to smaller deployment bundles. This also means slightly faster startup times on AWS Lambda, for example, and faster page initialisation for client-side code. 

For people working with TypeScript, V3 is also designed ground-up to support type definitions.

The new SDK is also written with Promises in mind, so there's no need to attach the ugly `.promise()` call after all API commands.

Finally, the new SDK supports flexible middleware, so there's no need to create ugly wrappers and interceptors to modify how the SDK calls AWS APIs. For example, I had to write some horrible code to add retries to all API Gateway methods when building `claudia.js`. This can be done nicely with middleware now.

## Key differences between V3 and V2

Instead of service objects that contain meaningful methods to access the API (for example, `s3.headObject` from the v2 SDK), in v3 each API endpoint maps to a `Command` object (for example `HeadObjectCommand`). The parameters and return types of the old and the new methods are mostly the same, so the execution code requires minimal or no changes (as long as you're using the low-level API commands, we'll come back to this later). Each service has a `Client` class, with a `send` method that accepts a command object.

For example, the following two snippets produce the same results. The first is written with v2 SDK, the second with v3:

```js
// v2
const aws = require('aws-sdk'),
  s3 = new aws.S3(),
  result = await s3.headObject({
    Bucket: 'some-bucket',
    Key: 'file-key',
    VersionId: 'file-version'
  }).promise();

// v3
const { S3Client, HeadObjectCommand } = require('@aws-sdk/client-s3'),
  result = await s3Client.send(new HeadObjectCommand({
    Bucket: 'some-bucket',
    Key: 'file-key',
    VersionId: 'file-version'
  }));
```

Notice that there's no `.promise()` in v3 calls, and that the parameters are pretty much the same. The result structure is the same as well, so this code can just be swapped. 

Also note that the v3 code requires the (minimal) client and a specific command, so JavaScript bundlers produce much smaller results. Here are the results for the two snippets above:

| variant | esbuild | esbuild --minify |
| --- | --- | --- |
| v2 | 13 MB | 5.4 MB |
| v3 | 1.4 MB | 666.9 KB |

## Commands map to API directly

The basic V3 SDK maps pretty much directly to the AWS service APIs, which means that the SDK clients are mostly automatically generated from AWS service definitions, including the documentation. The v2 documentation is amazing, with lots of examples to demonstrate how to use the key methods. V3 documentation is by comparison very basic. It's effectively a type reference, no more and no less. Hopefully as the SDK matures, someone at AWS will end up writing better docs. 

Although this looks as if it would be possible to just migrate between the SDK versions with a few lines of clever `sed` scripts, things get a bit more tricky with higher-level functions. The V2 SDK was closely related to the AWS service APIs, but not restricted by it. It also included a bunch of functions that made life much easier for JavaScript developers than if they used the bare-bones API directly. For example, the `S3` service object had a useful method for multipart batch uploading large files (`.upload()`) that doesn't exist in the API. Those methods do not exist as commands in the v3 SDK. Some utilities are provided in additional packages. This has the benefit of reducing bundle size for projects that do not need them, but it also means they are not as easy to discover as before. Here are some of the most important ones:

* Utility methods for converting between DynamoDB structures and JavaScript types (`aws.DynamoDB.Converter`) are no longer in the basic `DynamoDB` service, but in the  [`@aws-sdk/util-dynamodb`](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/modules/_aws_sdk_util_dynamodb.html)
* DynamoDB `DocumentClient` is now in [`@aws-sdk/lib-dynamodb`](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/modules/_aws_sdk_lib_dynamodb.html)
* The implementation for `s3.upload` is now in [`@aws-sdk/lib-storage`](https://github.com/aws/aws-sdk-js-v3/blob/main/lib/lib-storage/README.md)
* The implementation for `s3.createPresignedPost` is now in [`@aws-sdk/s3-presigned-post`](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/modules/_aws_sdk_s3_presigned_post.html)
* The implementation for `s3.getSignedUrl` is now in [`@aws-sdk/s3-request-presigner`](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/classes/_aws_sdk_s3_request_presigner.s3requestpresigner-1.html)

The last one is an example where things get a bit tricky. The method changes from synchronous to asynchronous (so you'll have to update all the callers to `await` or return a `Promise`), and the expiry argument is no longer directly in the parameters - you need to pass it as a separate option to the signer.

```js
//v2
const s3 = aws = require('aws-sdk'),
  s3 = new aws.S3(),
  result = s3.getSignedUrl('getObject', {
    Bucket: 'some-bucket', Key: 'file-key', Expires: expiresIn
  });

//v3
const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3'),
  { getSignedUrl } = require('@aws-sdk/s3-request-presigner'),
  command = new GetObjectCommand({Bucket: 'some-bucket', Key: 'file-key'}),
  result = await getSignedUrl(s3Client, command, {expiresIn});
```

Another place where good JS affordance utilities have been lost is retrieving the body of S3 objects. In v2, the `getObject` method had several utilities for consuming the result body into a string, or a buffer, or a stream. With v3 SDK, the result is a stream, and you'll have to convert it to string yourself. Here is a comparison of v2 and v3 code:

```js
//v2
const data = s3.getObject(params).promise(),
  return data.Body.toString();

// v3
const streamToString = function (stream) {
	const chunks = [];
  return new Promise((resolve, reject) => {
    stream.setEncoding('utf8');
    stream.on('data', (chunk) => chunks.push(chunk));
    stream.on('error', (err) => reject(err));
    stream.on('end', () => resolve(chunks.join('')));
  }),
  data = await s3Client.send(new GetObjectCommand(params));
return streamToString(data.Body);
```

## Client initialisation is different

Both v2 service objects and v3 clients can be customised with initialisation parameters, but there are subtle differences. For example, passing a `logger` object to the v2 service objects would provide amazingly useful logs before and after a call, with statistics. This saved me a ton of time troubleshooting problematic calls. The v3 SDK has a `logger` parameter, but only logs after a successful call, and without first turning it into JSON (so complex objects come out as `[Object object]`). In case of errors, when it's the most useful to have a log, v3 service clients log nothing. In case of stalled connections, v2 logs would show clearly where the client got stuck, but v3 logs show nothing. With v3 middleware injection, it's possible to replicate the useful v2 logger, but I'm hoping that someone at AWS will improve the basic logging in the future.

Another common customisation for SDK clients are HTTP parameters, especially timeouts. Those have now moved to a separate class (`NodeHttpHandler`), and need to be passed as `requestHandler` instead of `httpOptions`. Here are the equivalent snippets:

```js
//v2
const aws = require('aws-sdk'),
  s3 = new aws.S3({
    logger: console,
    httpOptions: {timeout: 10000, connectTimeout: 1000}
  });

//v3
const { S3Client } = require('@aws-sdk/client-s3'),
  { NodeHttpHandler } = require('@aws-sdk/node-http-handler');
  requestHandler = new NodeHttpHandler({
    connectionTimeout: 1000,
    socketTimeout: 10000
  }),
  s3Client = new S3Client({
    logger: console,
    requestHandler
  });
```

One particularly problematic aspect of the new initialisation is how it handles the `endpoint` argument. Both v2 and v3 allow specifying an alternative endpoint in the constructor, which is useful for testing and to get management APIs working (for example, for posting to websockets using the API Gateway Management API). However, v2 SDK can take the API stage as part of the endpoint as well, and v3 SDK ignores the stage and only keeps the hostname. Unfortunately, for websocket APIs created with a stage, the correct stage has to come before the request path for posting to websocket connections. That results in `PostToConnectionCommand` being completely broken out of the box (it reports a misleading `ForbiddenException`). We lost a good few hours on this one, trying to identify differences IAM permissions, only to realise that it's a difference in how SDK handles endpoints. 


I assume this will be changed at some point, because the only way to post to web sockets now with SDK v3 is to patch the request paths with a middleware. (There's an [active issue on GitHub about this](https://github.com/aws/aws-sdk-js-v3/issues/1830)). For anyone else hopelessly fighting with phantom `ForbiddenException` errors, here's the code to make it work. It expects the endpoint to have a stage at the end (eg produced by CloudFormation using `https://${ApiID}.execute-api.${AWS::Region}.amazonaws.com/${Stage}`).

```js
const {PostToConnectionCommand, ApiGatewayManagementApiClient}
    = require('@aws-sdk/client-apigatewaymanagementapi'),
	path = require('path'),
  client = new ApiGatewayManagementApiClient({endpoint, logger});
  // https://github.com/aws/aws-sdk-js-v3/issues/1830
  client.middlewareStack.add(
    (next) => async (args) => {
      const stageName = path.basename(endpoint);
      if (!args.request.path.startsWith(stageName)) {
        args.request.path = stageName + args.request.path;
      }
      return await next(args);
    },
    { step: 'build' },
  );
await apiClient.send(new PostToConnectionCommand({
  Data: JSON.stringify(messageObject),
  ConnectionId: connectionId
}));
```

## Exception structure is different

Lastly, v2 SDK throws exceptions with a `code` field in case of errors, that was useful for detecting the type of the error. That no longer exists in `v3`. Instead, check the `name` field. 

```js
try {
  await apiClient.send(new PostToConnectionCommand({
    Data: JSON.stringify(messageObject),
    ConnectionId: connectionId
  }));
} catch (e) {
  //v2
	if (e.code === 'GoneException') { return; }
  //v3
	if (e.name === 'GoneException') { return; }
  throw e;
}
```

## To Migrate or Not to Migrate

Version 3 SDK offers some clear advantages for front-end code (namely smaller bundles), and a cleaner async API, but it seems like it's a bit of a step back in terms of developer productivity. Also, at the time when I wrote this (May 2021), it still had quite a few rough edges. Most of the stuff is there, but it's difficult to find good documentation easily. There are still no firm deadlines on deprecating v2, but since v3 exists now, that will have to happen sooner or later, so it's worth starting to think about migration. The nice thing about how v3 is packaged is that it can co-exist with older v2 code, since the Node modules are completely different.

I'd suggest using v3 for any new code, and starting to move less critical items of old infrastructure, while being very careful about integration testing anything you switch over. Tiny subtle differences may surprise you.
