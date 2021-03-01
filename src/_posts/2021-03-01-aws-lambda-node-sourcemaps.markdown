---
layout: post
title:  "How to use source maps in AWS Lambda with Node.js"
excerpt: "If you ever opened your CloudWatch logs and saw that the error happened in the /var/task/index.js:1:2345, this post is for you. It'll teach you how to transform this meaningless stack trace into something that matches your source code and you understand."
date: 2021-03-01 14:00:00 +0200
categories: Serverless
author_name : Slobodan Stojanović
author_url : /author/slobodan
author_avatar: slobodan.jpg
twitter_username: slobodan_
show_avatar: true
read_time: 20
feature_image: sourcemaps.png
show_related_posts: false
square_related: recommend-slobodan
---

If you ever opened your CloudWatch logs and saw that the error happened in the `/var/task/index.js:1:2345`, this post is for you. It'll teach you how to transform this meaningless stack trace into something that matches your source code and you understand.

> TL;DR: If you are here just for the solution, not the article itself, the easiest way to get the useful Error stack traces is to add the following environment variable to your Lambda function: `NODE_OPTIONS=--enable-source-maps`. This works only for Node.js v12+, and you'll need to deploy your source maps to your Lambda function with your code. See the rest of the article or the summary at the bottom of the article for more info.

![](/img/sourcemaps.png)

Building and bundling code is no longer a front end only thing, especially with the increasing popularity of TypeScript. If you are using TypeScript for your back end, you often build it and then run it as a regular Node.js application.

Even if you are not using TypeScript, building a serverless application with Node.js and shared dependencies require some type of bundling. In addition to that, smaller code size decreases your serverless functions' start time, making minification and tree shaking popular for the back end code.

There are many techniques for bundling and minifying a serverless function's code. I would recommend checking the excellent [esbuild](https://esbuild.github.io), as it can build more than a hundred Lambda functions in [seconds](https://twitter.com/slobodan_/status/1332399554356973568). However, regardless of the technique you choose, you'll face the same problem: the stack trace in your Cloud Watch logs becomes useless.

For example, if you look in the error log in your Cloud Watch logs console, you'll see something similar to the following: `/var/task/index.js:1:2345`. The error occurred at the 2345th character of the first line of your minified function's code. The stack trace like this one is not useful, as this one line contains all of your code combined with the Node.js modules you are using.

A helpful stack trace should show the exact line of the file where the error occurred. To display the actual file path and the line of the error, JavaScript needs source maps.

## Source maps

A source map allows JavaScript to map a bundled (and often minified) JavaScript file back to its original (unbundled) source code.

Most popular build tools, including esbuild and Webpack, can generate a source map file when bundling a JavaScript or TypeScript application. You enable source maps with a few configuration lines or with a build flag.

A JavaScript engine queries that source map file to get the required info and display the actual file path and the error line when the error occurs.

The bundled file contains a comment similar to the following code snippet that tells the JavaScript engine where to look for a source map file:

```javascript
//# sourceMappingURL=index.js.map
```

Not all source maps are the same, but the typical source map file looks similar to the following code snippet:

```json
{
  "version": 3,
  "sources": ["../../functions/no-source-maps/lambda.ts", "../../functions/no-source-maps/main.ts"],
  "sourcesContent": ["import { doSomething } from './main'\n\nexport async function handler() {\n  // Can we log the trace with the following line?\n  console.trace()\n\n  // And then we'll invoke the function that returns an error\n  return doSomething()\n}", "export function doSomething() {\n  // Get a random number\n  const randomNumbar = getRandomNumber(0, 100);\n\n  // And pass it to the function that throws an error\n  functionThatThrowsAnError(randomNumbar);\n}\n\nfunction getRandomNumber (min: number, max: number): number {\n  return Math.floor(Math.random() * (max - min + 1)) + min;\n}\n\nfunction functionThatThrowsAnError(number: number) {\n  console.log('A function that throws an error is invoked');\n\n  throw new Error(`Received number ${number}`);\n}"],
  "mappings": "qIAAA,2BCAO,aAEL,GAAM,GAAe,EAAgB,EAAG,KAGxC,EAA0B,GAG5B,WAA0B,EAAa,GACrC,MAAO,MAAK,MAAM,KAAK,SAAY,GAAM,EAAM,IAAM,EAGvD,WAAmC,GACjC,cAAQ,IAAI,8CAEN,GAAI,OAAM,mBAAmB,KDbrC,mBAEE,eAAQ,QAGD",
  "names": []
}
```

The crucial part of the source map file is the "mappings" property. These Base64 variable-length quantity strings represent the actual mapping from the bundled file to its original source. Base64 VLQ strings and an in-depth explanation of the source maps are beyond the scope of this article, but if you want to learn more, you can read this ["Source Maps from top to bottom" article](https://indepth.dev/posts/1230/source-maps-from-top-to-bottom).

## How to enable source maps in AWS Lambda with Node.js

As mentioned above, the build tool you are using probably knows how to produce source maps. Once you enable source maps, the output of your build command will contain multiple files. If you bundle your function's code to the `lambda.js` file, you'll also get the `lambda.js.map`.

Even if you upload both files to your Lambda function, the error in your Cloud Watch logs will still show the meaningless stack trace. That's because Cloud Watch can't read your source maps. You can try to translate the error to something meaningful locally, using the source map file, but that's far from a good developer experience. Fortunately, there are two simple ways to fix this.

### Using the source-map-support module

For a long time, the only way to make Cloud Watch logs to use the source maps was by installing some third-party library. I used the excellent [source-map-support](https://www.npmjs.com/package/source-map-support) Node module, as it was easy to install and set up, and it works fine.

To use this module, you need to install it from npm by running the `npm install source-map-support` command, and then import and install it at the top of your Lambda function with following code snippet to import it:

```javascript
require('source-map-support').install();
```

It is even more comfortable with ES6 or TypeScript, as you can simply do the following:

```typescript
import 'source-map-support/register'
```

With this single line, your stack traces become way more useful. You just need to make sure that you upload your source maps with your functions code.

### Enabling the native source map support for Node 12+

Node.js finally added support for source maps in v12.12.0. Luckily, AWS Lambda runtime for Node.js v12 (`nodejs12.x`) comes with this support.

However, source maps support is still experimental, and it requires the [`--enable-source-maps`](https://nodejs.org/dist/latest-v12.x/docs/api/cli.html#cli_enable_source_maps) flag.

To add this flag and enable source maps, you need to add the following environment variable to your Lambda functions:

```
NODE_OPTIONS=--enable-source-maps
```

And that's it! You do not need to install any additional dependencies. As long as you have this environment variable and your source map file in your Lambda function, you'll be able to see the meaningful error stack traces. 

## Testing the solutions

Let's build a simple serverless app to test these solutions. We'll use the [AWS Cloud Development Kit (CDK)](https://aws.amazon.com/cdk/) for this app, but you can do a similar test with your favorite deployment tool.

Initialize an empty AWS CDK application by running the following command:

```bash
npx cdk init app --language typescript
```

This command will create a new serverless project with a structure similar to the following:

```bash
.
├── README.md
├── bin
│   └── lambda-node-sourcemaps.ts
├── cdk.json
├── jest.config.js
├── lib
│   └── lambda-node-sourcemaps-stack.ts
├── package-lock.json
├── package.json
├── test
│   └── lambda-node-sourcemaps.test.ts
└── tsconfig.json
```

Now that we have our project ready let's create three test Lambda functions. We'll use the [Amazon Lambda Node.js Library](https://docs.aws.amazon.com/cdk/api/latest/docs/aws-lambda-nodejs-readme.html) CDK construct. You can learn more about this and other CDK constructs in the [AWS Construct Library](https://docs.aws.amazon.com/cdk/api/latest/docs/aws-construct-library.html).

Run the following command in the project folder to install the Amazon Lambda Node.js Library module:

```bash
npm i @aws-cdk/aws-lambda-nodejs
```

The Amazon Lambda Node.js Library will automatically bundle our functions using the excellent [esbuild](https://esbuild.github.io). If you have the esbuild module installed, CDK will use it to create bundles. Otherwise, bundling will happen in a [Lambda-compatible Docker container](https://hub.docker.com/r/amazon/aws-sam-cli-build-image-nodejs12.x).

I prefer a local copy of the esbuild module because it increases the build speed. Let's run the following command to install the esbuild module as a dev dependency:

```bash
npm install --save-dev esbuild
```

Let's create three Lambda functions to test and compare the following three scenarios:

- A Lambda function without source map support
- A Lambda function with the source-map-support module
- A Lambda function with native source maps

I like putting functions in the "functions" folder, so let's start by creating the "functions" folder in the root folder of your CDK project. Once you create this folder, we'll start creating the funtions.

If you want to learn more about building serverless applications with Node.js, you can [subscribe to my mailing list](https://slobodan.me/subscribe) and get more tips, articles, and free workshops.

### A Lambda function without source map support

Let's start with a simple Lambda function without source maps. To add this function, open the "lib/lambda-node-sourcemaps-stack.ts" file, which represents your CDK stack. Import the `NodejsFunction` from the `@aws-cdk/aws-lambda-nodejs` CDK construct by adding the following line at the top of this file:

```typescript
import { NodejsFunction } from '@aws-cdk/aws-lambda-nodejs';
```

Then add the following to the constructor of your CDK stack:

```typescript
// A Lambda function without source maps support
const noSourceMapsFunction = new NodejsFunction(this, 'no-source-maps', {
  entry: 'functions/no-source-maps/lambda.ts',
  handler: 'handler',
  bundling: {
    sourceMap: true,
    minify: true
  }
})
```

This code will create a Lambda function with the source code in the "functions/no-source-maps/lambda.ts" file as the entry. It'll also use esbuild to create the JavaScript file from that entry file and all the imported files and modules, and enable minification and generate the source maps.

If this code might seem a bit more complicated for you, feel free to visit the [Github repository](https://github.com/serverlesspub/lambda-node-sourcemaps), clone and deploy the final version of the code, and jump to the "Testing the functions" section below.

The next step is creating the "no-source-maps" folder in the new "functions" folder.

To make our stack trace a bit more fun, let's create two files in the "no-source-maps" folder: lambda.ts and main.ts. The lambda.ts file will simply invoke the main.ts function, and the main.ts functions will generate a random number and throw an error with that number. Let's also add the `console.trace()` to the lambda.ts function, just to test if it's supported and if it's using the same source map support.

Create the lambda.ts file with the following content:

```typescript
import { doSomething } from './main'

export async function handler() {
  // Can we log the trace with the following line?
  console.trace()

  // And then we'll invoke the function that returns an error
  return doSomething()
}
```

Then create the main.ts file with the following content:

```typescript
export function doSomething() {
  // Get a random number
  const randomNumbar = getRandomNumber(0, 100);

  // And pass it to the function that throws an error
  functionThatThrowsAnError(randomNumbar);
}

function getRandomNumber (min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function functionThatThrowsAnError(number: number) {
  console.log('A function that throws an error is invoked');

  throw new Error(`Received number ${number}`);
}
```

The first function looks good, let's create the second one with the `source-map-support` module.

### A Lambda function with the source-map-support module

Let's start by adding the following code to the "lib/lambda-node-sourcemaps-stack.ts" file:

```typescript
// A Lambda function with the source-map-support module
const sourceMapSupportFunction = new NodejsFunction(this, 'source-map-support', {
  entry: 'functions/source-map-support/lambda.ts',
  handler: 'handler',
  bundling: {
    sourceMap: true,
    minify: true
  }
})
```

The new function is similar to the previous function. The only difference is the entry path.

Then install the  `source-map-support` Node module from npm, by running the following command from your terminal:

```bash
npm install source-map-support
```

Create the "source-map-support" folder in the "functions" folder. To keep things simple, copy the content of the "functions/no-source-maps" folder to the new "functions/source-map-support" folder.

Finally, open the "functions/source-map-support" file, and add the following to the top of the file:

```typescript
// Allow CloudWatch to read source maps
import 'source-map-support/register'
```

### A Lambda function with native source maps

For the Lambda function with the native source maps support, we can reuse the same code from the first Lambda function. Open the "lib/lambda-node-sourcemaps-stack.ts" file, and add the following:

```typescript
// A Lambda function with the native source map support
const nativeSourceMaps = new NodejsFunction(this, 'native-source-maps', {
  entry: 'functions/no-source-maps/lambda.ts',
  handler: 'handler',
  environment: {
    NODE_OPTIONS: '--enable-source-maps'
  },
  bundling: {
    sourceMap: true,
    minify: true
  }
})
```

As you can see, the only difference is adding the "NODE_OPTIONS" environment variable with the following value: `--enable-source-maps`.

### Exposing an API

Let's also add a simple API Gateway HTTP API to be able to test our functions. To do so, install the `@aws-cdk/aws-apigatewayv2` and `@aws-cdk/aws-apigatewayv2-integrations` CDK constructs by running the following command:

```bash
npm install @aws-cdk/aws-apigatewayv2 @aws-cdk/aws-apigatewayv2-integrations
```

The open the "lib/lambda-node-sourcemaps-stack.ts" file one more time, and add the following to the top of the file:

```typescript
import { HttpApi } from '@aws-cdk/aws-apigatewayv2';
import {} from '@aws-cdk/aws-apigatewayv2-integrations';
```

And finally, create the API and the routes by adding the following code to your CDK stack:

```typescript
// An HTTP API
const api = new HttpApi(this, 'api', {})

const noSourceMapsFunctionIntegration = new LambdaProxyIntegration({
  handler: noSourceMapsFunction
})

api.addRoutes({
  path: '/no-source-maps',
  methods: [HttpMethod.GET],
  integration: noSourceMapsFunctionIntegration
})

const sourceMapSupportFunctionIntegration = new LambdaProxyIntegration({
  handler: sourceMapSupportFunction
})

api.addRoutes({
  path: '/source-map-support',
  methods: [HttpMethod.GET],
  integration: sourceMapSupportFunctionIntegration
})

const nativeSourceMapsIntegration = new LambdaProxyIntegration({
  handler: nativeSourceMaps
})

api.addRoutes({
  path: '/native-source-maps',
  methods: [HttpMethod.GET],
  integration: nativeSourceMapsIntegration
})
```

To get the API URL, add this to the bottom of your CDK stack (inside the constructor):

```typescript
new cdk.CfnOutput(this, 'ApiUrl', {
  value: api.url || ''
})
```

This will output your API URL once the CDK stack is deployed.

### Testing the functions

To test the functions, deploy the CDK stack by navigating to your project folder in your terminal and running the following command:

```bash
npm run cdk deploy
```

This command will take a few minutes, and it should successfully deploy your serverless application to AWS. Once the deployment is finished, you'll see the output similar to the following:

```bash
Outputs:
LambdaNodeSourcemapsStack.ApiUrl = https://a11a11aaaa.execute-api.eu-central-1.amazonaws.com
```

The URL represents your API's base URL. Your URL may be slightly different than the one above, depending on the region you are using.

You might also need to run the `npm run cdk bootstrap` command if you get an error during the deployment. You can read more about bootstrappingCDK apps in [the official documentation](https://docs.aws.amazon.com/cdk/latest/guide/bootstrapping.html).

To test the API, you can visit the base URL with the path for the endpoint that you want to try. For example, for a function with no source maps, you can visit the `https://a11a11aaaa.execute-api.eu-central-1.amazonaws.com/no-source-maps` in your browser (make sure to replace the base URL with your API's base URL).

The API will return the error, as expected. Let's see the error log. Log in to the AWS Web console, go to the CloudWatch section, select logs, and find the log group for your function. Select the latest (and most likely only) log stream, and you should see something similar to the following screenshot:

![](/img/no-source-maps.png)

As we can see, the error trace is not useful, as it points to the `index.js:1:331`. We can also see that the `console.trace` returns `undefined`, which means that it is not supported. The function is fast, as it generates a random string, so our billed duration is just 35 ms in this case.

Let's try the next endpoint! Visit the `https://a11a11aaaa.execute-api.eu-central-1.amazonaws.com/source-map-support` in your browser, and again make sure to replace the base URL with your API's base URL. Then go to the CloudWatch logs, and you'll see something similar to the following screenshot:

![](/img/source-map-support.png)

The error stack trace is now much more useful, as we can see that the error occurs in line 16 of the `main.ts` file. The `console.trace` command is still not supported. But another interesting thing is the billed duration. It's 821 ms this time! As the function does exactly the same as the previous one, the overhead is slightly higher than expected. The billed duration requires more tests, but the initial result is unexpected.

Then try the last endpoint. Visit the `https://a11a11aaaa.execute-api.eu-central-1.amazonaws.com/native-source-maps` in your browser. Then go to the CloudWatch logs for this function, and you'll see something similar to the following screenshot:

![](/img/native-source-maps.png)

The source maps work fine! The output is slightly different, but as long as we have the correct line numbers in our Error stack trace, the format is not that important. As expected, the `console.trace` command is still not supported, as we are using the same Node.js runtime for our Lambda function. And the billed duration is slightly higher than the one for the initial function, but this can be just a coincidence, and it needs more tests before any further conclusions.

## Summary

Here's a quick summary:

- Source maps are an essential part of debugging each JavaScript project that bundles multiple files and external dependencies to single or multiple files. They are no longer front-end only thing, as we often bundle our back-end applications.
- Enabling source maps in your favorite build tools (i.e., Webpack or esbuild) often requires adding a single flag or parameter.
- Serverless applications on AWS store logs in CloudWatch logs by default, and CloudWatch has no built-in source maps support.
- To add the source map support to your serverless application, add the following environment variable to your Lambda function: NODE_OPTIONS=--enable-source-maps. This works only for Node.js v12+, and you'll need to deploy your source maps to your Lambda function with your code.
- For Node.js runtimes before v12.x, you can install the source-map-support Node module from npm and import and register it in each function in your project.

If you want to learn more about building serverless applications with Node.js, you can [subscribe to my mailing list](https://slobodan.me/subscribe) and get more tips, articles, etc.