---
layout: post
title:  "Chapter 6: Testing AppSync applications - Unit testing"
date: 2022-03-21 12:00:00 +0200
author_name : Slobodan Stojanović
author_url : /author/slobodan
author_avatar: slobodan.jpg
twitter_username: slobodan_
show_avatar: true
read_time: 18
feature_image: running-serverless-realtime-graphql-applications-with-appsync-cover.jpg
show_related_posts: false
permalink: /unit-testing-appsync-apps/
---

<div style="border: 1px solid #FFE58F; background: #FFFBE6; border-radius: 4px; padding: 12px 24px; width: 100%; margin: 0 auto 20px;">
  <p>This is an excerpt from Chapter 6 of <i><a href="http://localhost:4000/running-serverless-realtime-graphql-applications-with-appsync/">Running Serverless: Realtime GraphQL applications with AppSync</a></i>, a book by Gojko Adzic, Aleksandar Simović, and Slobodan Stojanović.</p>

  <p>Our book is not published yet. Your feedback means a lot to us, so please fill out the short survey at the end of this article to help us polish the story.</p>

  <p style="margin-bottom: 0px">Please don't share this article. We'll publish a sharable version of this article as soon as the early version of the book is ready.</p>
</div>

Creating the first VTL template wasn't as hard as Ant expected. However, the development cycle takes a lot of trial and error and Ant feels the progress is slow. It is easy to make mistakes, especially because Ant doesn't have experience with VTL. Mistakes are OK as long as he can catch and fix them fast. However, with AppSync and VTL templates, Ant needs to deploy the application, test it, debug the VTL output and dig through AppSync logs.

VTL templates can contain a significant amount of business logic, so it's important to find a better way to write and debug them. Web apps for generating AppSync VTL templates, such as Graphboss, are excellent, but Ant still needs to copy and paste his templates to verify them. However, someone else can edit a template without testing it in one of these applications.

Ant thought about what he usually did for non-serverless and non-GraphQL apps.

He would run the application locally to confirm that everything works, and he would also write tests. A typical application often requires three types of tests: unit, integration, and end-to-end (Figure 6.1). Because Ant likes the idea of the Test Pyramid¹, he would write:

1. Many unit tests to verify that his business logic works. These tests are fast and cheap because they test Ant's functions in isolation.
2. Some integration tests to ensure that integration between units works, for example, if the data is saved to the database correctly.
3. A few end-to-end tests to verify that the application works as expected.

![Figure 6.1: Testing a typical three-tier application](/img/ch_testing_appsync/testing-non-serverless-app.png)
_Figure 6.1: Testing a typical three-tier application_

"There are two big questions at the moment. Can I run my AppSync app locally, and how do I test it? Let's start with the first one. My app is a GraphQL application, so I should be able to run it locally. But how do I do that with AppSync?" Ant wonders. "There's a quick way to find that out!"

## Testing AppSync applications

After searching the web for a few minutes, Ant sends a message to Claudia, asking if he could run his AppSync application locally. A moment later, she replies, "In theory, it is possible to run the app locally using the simulator from the [AWS Amplify](https://aws.amazon.com/amplify/), but it's tricky to set up. However, you can use AWS Amplify simulator to run your unit tests."

"Wait, what's Amplify?" Ant asked.

"Don't worry about Amplify right now," Claudia replies, "just use the simulator, and I'll explain more later."

> ### AWS Amplify
> 
>  Amplify is a framework for building web apps on top of AWS consisting of many different tools which we will cover in the Introduction to AWS Amplify chapter. In this chapter we'll only focus on using the simulator tool for testing purposes.

## What to test in AppSync applications

Ant decides to start with the Amplify simulator for unit tests. But before he starts, he wonders what he should test in an AppSync application and if the testing automation pyramid still applies?

Ant sent another message to Claudia: "Hey, but what should I test in an AppSync application?"

"That's a good question!" Claudia replies. "Testing an AppSync application still requires all three types of tests (unit, integration, and end-to-end). However, AWS already tests some parts of your application, so the scope of your tests is slightly different. It's easier to explain this with a diagram. Give me a minute!"

A few minutes later, Claudia sent a diagram (Figure 6.2) with the following explanation:

1. With unit tests, you verify that your VTL templates render as expected. Use the AWS AppSync simulator to render your VTL templates with specified parameters and confirm the response.
2. AWS already tests part of the system, so writing integration tests for that part is either impossible or redundant. For example, AWS ensures that the communication between GraphQL endpoint and VTL templates works.
3. Your integration tests verify that integration between GraphQL and data sources works. For example, you should test if the data is stored to DynamoDB when sending a mutation.
4. As with any other application, an AppSync app benefits from end-to-end tests.

![Figure 6.2: Testing an AppSync application](/img/ch_testing_appsync/testing-serverless-app.png)
_Figure 6.2: Testing an AppSync application_

"This is perfect, thanks!" Ant replies. "By the way, what's the difference between integration and end-to-end tests in an AppSync application? I need to send an HTTP request for integration tests, right?"

"Correct!" replies Claudia. "Remember, the Testing Pyramid argues that end-to-end tests through the UI are: brittle, expensive to write, and time-consuming to run. So it suggests that you should have an intermediate layer of tests that have many benefits of end-to-end tests, but without the complexities introduced by UI frameworks."

"Makes sense. Where should I start?"

### Simulating AppSync for local tests

You need the Amplify AppSync simulator for unit tests. It's part of the Amplify CLI, but you can install it as a separate package from [npm](https://www.npmjs.com/package/amplify-appsync-simulator).

The Amplify AppSync simulator package is not built for independent use, so it has no documentation. You might need to dig through the source code to find how to use it and that Amplify can introduce breaking changes at any point. However, it's still worth using because it takes time and energy to write and maintain a VTL renderer with AppSync's utility functions.

The AppSync simulator is written in TypeScript, making the simulator integration easier. It's a class with many methods. However, the best place to start is [the Velocity Template class](https://github.com/aws-amplify/amplify-cli/blob/master/packages/amplify-appsync-simulator/src/velocity/index.ts) in the AppSync simulator's "velocity" folder. The VTL simulator provides a template and input parameters and renders it.

### AppSync simulator setup

Ant opens his terminal, navigates to the Upollo project folder and installs the Amplify AppSync simulator with the following command:

```bash
npm install amplify-appsync-simulator --save-dev
```

He picks his favourite Node.js testing library, [Jest](https://jestjs.io). Amplify AppSync simulator is a Node.js tool, so any testing library for Node.js works with it. He runs the following command in his terminal to install Jest and Jest TypeScript transformer:

```bash
npm install jest ts-jest --save-dev
```

He also creates the Jest configuration file, named `jest.config.js`, in the root folder of the Upollo project. This configuration file is written in JavaScript instead of TypeScript because it tells Jest how to read TypeScript. Ant can write it in TypeScript, but that would require additional configuration. At the moment, he wants a simple setup to start writing tests as fast as possible. In his Jest configuration file, Ant writes the following:

```javascript
module.exports = {
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  testMatch: ['**/*.test.ts'],
  transform: {
    '^.+\\.tsx?$': 'ts-jest'
  }
};
```

Jest knows that it needs to run the tests using the Node.js environment. It also knows that it can find tests in the `test` folder at the root of the project and that all tests have`.test.ts` extension. Finally, it knows that it needs to apply the Jest Typescript transformer to run all files with `ts` and `tsx` extensions.

Then, Ant creates the `test` folder in the project root. The Amplify AppSync simulator library has a lot of boilerplate code, so Ant wants to write a small abstraction helper. He creates the `helpers` folder inside the `test` folder and a file named `vtl-simulator.ts` inside it.

He opens the `vtl-simulator.ts` file in his VS code and writes the following lines to import the Amplify AppSync simulator and its velocity file as dependencies:

```typescript
import { AmplifyAppSyncSimulatorAuthenticationType, AmplifyAppSyncSimulator } from 'amplify-appsync-simulator';
import { VelocityTemplate, AppSyncVTLRenderContext } from 'amplify-appsync-simulator/lib/velocity';
```

Ant's unit tests read VTL templates and GraphQL schema from the local disk, so he imports the `fs` and `path` modules:

```typescript
import { readFileSync } from 'fs';
import { join } from 'path';
```

Ant learns from the documentation that he needs to provide the request context and request info for the Velocity render method. However, it seems that these don't affect the VTL templates he is planning to write, so he decides to make default values to omit to pass them in each unit test. He also imports the `API_KEY` type from the AppSync simulator to please the TypeScript type checking. As AppSync simulator types are not strictly defined, and Ant is lazy to spend a lot of time finding the correct types, he sets the `any` type in a few places. Then he creates a path to the GraphQL schema because he'll need to load it later for the AppSync simulator and ends up with the following lines of code:

```typescript
const { API_KEY } = AmplifyAppSyncSimulatorAuthenticationType;

const defaultRequestContext: any = {
  headers: {},
  requestAuthorizationMode: API_KEY
};
const defaultInfo: any = {
  fieldNodes: [],
  fragments: {},
  path: {
    key: '',
  }
};
const defaultSchemaPath = join(__dirname, '..', '..', 'schema.graphql');
```

Ant creates the `VTLSimulator` class, declares the `vtl` variable as `any`, and hopes that Claudia will never see these `any` types.

```typescript
export class VTLSimulator {
  vtl: any;
  // TODO: Add constructor and render method
}
```

Then he writes the constructor of his new class that accepts the VTL template path as a parameter. The constructor also allows Ant's team to overwrite the path to the GraphQL schema if they need to pass a different one.

Ant loads the VTL template and the GraphQL schema using the `readFileSync` function from the `fs` module in the constructor. He can read these files asynchronously, but this is a helper for his unit tests, so he decides to keep it as simple as possible.

Then he creates the instance of the `AmplifyAppSyncSimulator` class and calls the `init` method to initialise the simulator. The `init` method requires a GraphQL schema and some basic AppSync settings, such as name and the default authentication type. At this point, Ant does not care about the authorisation type, so he passes the `API_KEY`. He'll change it later if he needs to.

After initialising the AppSync simulator, Ant creates an instance of the `VelocityTemplate` class by passing the VTL template content and the simulator as parameters.

```typescript
  constructor(filePath: string, schemaFilePath = defaultSchemaPath) {
    const content = readFileSync(filePath, 'utf8');
    const graphQLSchema = readFileSync(schemaFilePath, 'utf8');
    const simulator = new AmplifyAppSyncSimulator();
    simulator.init({
      schema: {
        content: graphQLSchema,
      },
      appSync: {
        name: 'name',
        defaultAuthenticationType: {
          authenticationType: API_KEY
        },
        additionalAuthenticationProviders: []
      },
    });
    this.vtl = new VelocityTemplate({ content }, simulator);
  }
```

Ant also creates the `render` method in his `VTLSimulator` class. He puts the `templateParameters` as the only argument of this method. He'll use this argument to pass the part of the AppSync context he needs to render the template.

In the render method, he uses the `templateParameters` to extend the default context, renders the template using the `VelocityTemplate` instance and the default values he defined, and returns the result.

```typescript
  render(templateParameters: Partial<AppSyncVTLRenderContext>): any {
    const ctxParameters = { source: {}, arguments: { input: {} }, ...templateParameters };
    return this.vtl.render(
      ctxParameters,
      defaultRequestContext,
      defaultInfo
    );
  }
```

The new `VTLSimulator` helper should make his unit tests clean and simple. However, his linter complains about the `any` types. He puts the following line at the top of his new helper file:

```typescript
/*eslint @typescript-eslint/no-explicit-any: "off" */
```

"I really hope that Claudia will never see this," Ant thinks while he proudly looks at his VTL Simulator helper with a smile on his face.

### Creating Unit tests for VTL templates

"Where should I start with my unit test for the `get-survey-by-id-request.vtl` template?" Ant wonders while grinding coffee beans for a new cup of espresso. "At some point, Claudia mentioned that I should check for the errors first. That sounds like a good idea." He would do the same for non-serverless applications. "How do I check the errors?" 

After a few trials and errors, Ant finds out that the AppSync VTL engine returns the following values when it renders a template:

- `errors` - a list of errors that occurred during rendering.
- `hadExceptions` - a boolean that indicates if the rendering had errors or not.
- `isReturn` - a boolean value that indicates if the result is a return value or not.
- `stash` - a map of stashed values, available during a single resolver execution.
- `result` - a rendered template result.

Ant can test the errors by verifying that the `hadExceptions` value is set to `false`, or he can check if the `errors` array is empty. Checking both values sounds redundant. The second one sounds easier because he can also check if the `errors` array contains a specific error when he throws one.

After trying a few examples with the local renderer and a deployed application, Ant sees some differences between his simulator and an actual AppSync VTL engine. These differences are not blocking at the moment. For example, in the AppSync VTL engine, the `isReturn` value is `true` if the response resolver template is rendered. The local simulator does not know if the template is a request or response resolver template, so the only way to make the `isReturn` value true is to use [the `#return` directive](https://docs.aws.amazon.com/appsync/latest/devguide/resolver-util-reference.html#aws-appsync-directives).

"Now I understand why Claudia mentioned that my unit tests are as good as my mocks." Ant nods. "These unit tests can help us write or edit VTL templates faster and catch some important issues. However, we'll always need to verify them in the deployed AppSyn API."

Testing the `isReturn` value doesn't make much sense. However, the `stash` value sounds like a good candidate for testing. Ant can verify if the stash is empty or not. He is not using it now, but he will use it for sure when he starts writing more complicated VTL templates.

Finally, Ant needs to verify that the `result` value actually contains the rendered value he expects. There are also minor differences between the simulated `result` value and the actual AppSync `result` value. For example, the AppSync VTL engine always transforms text to text, but the local simulator converts the JSON values to a JavaScript object. Which makes them easier to verify in Jest.

Ant's verification process looks similar to Figure 6.3.

<img src="/img/ch_testing_appsync/vtl-result-verification.png" alt="Figure 6.3: VTL renderer result verification process" width="250" style="display: block; text-align: center; margin: 0 auto;">
_Figure 6.3: VTL renderer result verification process_

Ant needs to test both his request and response mapping templates.

### Testing request mapping templates

Ant starts with the request mapping template. He creates a new file in his `test` folder, and names it `get-survey-by-id-request.vtl.test.ts`.

He opens the new test file in VS Code, and imports the VTL simulator from `helpers` folder.

```typescript
import { VTLSimulator } from './helpers/vtl-simulator';
```

Ant imports the `join` function from the `path` module. He uses the `join` function to create an absolute path to the VTL template file he wants to test and uses that path to create the instance of the VTL simulator class.

```typescript
import { join } from 'path'
const templatePath = join(__dirname, '..', 'vtl', 'get-survey-by-id-request.vtl')
const velocity = new VTLSimulator(templatePath)
```

He creates an empty `describe` block for his tests and names it `get-survey-by-id-request.vtl`. This name is not creative, but it's descriptive, so he likes it.

```typescript
describe('get-survey-by-id-request.vtl', () => {
  // TODO: Write unit tests
}
```

Ant is finally ready to write his first unit tests.

"Where should I start?" he wonders. "My request template is simple. I can test what happens when I pass a correct ID and an incorrect ID. My GraphQL schema will make sure that I always have the ID and that it is a string, so I do not need to test if the ID exists or not. I'll start with a test that should return the survey with the ID I provided."

He creates a first test inside the `describe` block and names it "should return the survey with the provided ID."

At the beginning of the test, he creates a context object with the following arguments: `{ "id": "First" }`. Then he passes the test context to the `velocity.render` method to render a template and stores the result in the `rendered` variable.

Finally, he checks the `rendered.errors` and `rendered.results` values. The `errors` array should be empty, and the result should have a `payload` that represents the survey with the ID "First," and a version equal to `"2018-05-29"`.

```typescript
  test('should return the survey with the provided ID', () => {
    const ctxValues = { arguments: { id: 'first' } }
    const rendered = velocity.render(ctxValues)
    expect(rendered.errors).toEqual([])
    expect(rendered.result).toEqual({
      payload: {
        id: 'first',
        question: 'What is the meaning of life?',
      },
      version: '2018-05-29',
    })
  })
```

"That wasn't hard. I hope it works! But let's write the other one before running them."

He creates another test in the `describe` block and names it "should not return payload when survey is not found."

The second test is similar to the first one. Ant creates a test context, with a crucial difference -- the ID is `"x"`, and then uses the `velocity.render` method to render the template. Then he checks that there are no errors and that the result has a version without a payload.

"Maybe I should throw an error when the survey with an ID is not provided. That would improve both my code and my tests. However, this is just a test resolver, so I'll make sure to throw a meaningful error when I connect the resolver to a database."

```typescript
  test('should not return payload when survey is not found', () => {
    const ctxValues = { arguments: { id: 'x' } }
    const rendered = velocity.render(ctxValues)
    expect(rendered.errors).toEqual([])
    expect(rendered.result).toEqual({
      version: '2018-05-29',
    })
  })
```

Ant opens his terminal and navigates the project folder. Then he runs the `npm test` command to run his tests. Jest is running. One second. Two. Three. Five. Eight. Suspension is killing him. And finally, after almost 13 seconds, he sees the green `PASS` on his screen. Both tests passed with the following feedback in his terminal:

```bash
 PASS  test/get-survey-by-id-request.vtl.test.ts (12.433 s)

Test Suites: 1 passed, 1 total
Tests:       2 passed, 2 total
Snapshots:   0 total
Time:        13.383 s
Ran all test suites.
```

"Woohoo! It works."

### Testing response mapping templates

"Let's do it again," Ant thinks while he creates another file in his `test` folder and names it `get-survey-by-id-response.vtl.test.ts`. "I can test the error first for the response template."

He opens the new file in his VS Code and imports his VTL simulator and response VTL template at the top, creating an instance of the VTL simulator class.

```typescript
import { join } from 'path'
import { VTLSimulator } from './helpers/vtl-simulator'
const templatePath = join(__dirname, '..', 'vtl', 'get-survey-by-id-response.vtl')
const velocity = new VTLSimulator(templatePath)
```

Then he creates a new `describe` block with the name "get-survey-by-id-response.vtl." Ant writes the first test "should return an error if survey is not found." Then he creates an empty context object and renders a template with it. Ant expects that the `errors` array contains the "Survey not found" error. The `result` should be an empty object.

He creates another test: "should return the survey with the provided ID." In this test, he checks that the errors array is empty and that the result is equal to the result he passes in the arguments: `{ something: true }`.

```typescript
describe('get-survey-by-id-response.vtl', () => {
  test('should return an error if survey is not found', () => {
    const ctxValues = {}
    const rendered = velocity.render(ctxValues)
    expect(rendered.errors).toEqual([
      new Error('Survey not found.'),
    ])
    expect(rendered.result).toEqual({})
  })
  
  test('should return the survey with the provided ID', () => {
    const ctxValues = { result: { something: true } }
    const rendered = velocity.render(ctxValues)
    expect(rendered.errors).toEqual([])
    expect(rendered.result).toEqual({
      something: true
    })
  })
})
```

Ant opens his terminal, runs the `npm test` command again, and sees two green "PASS" statuses 10 seconds later:

```bash
 PASS  test/get-survey-by-id-request.vtl.test.ts
 PASS  test/get-survey-by-id-response.vtl.test.ts (9.427 s)

Test Suites: 2 passed, 2 total
Tests:       4 passed, 4 total
Snapshots:   0 total
Time:        9.924 s, estimated 13 s
Ran all test suites.
```

A few minutes later, Ant sends a message to Claudia to brag about his new testing skills.

"Bravo! But don't pop the champagne bottle yet," Claudia says with a smiley, "let's write some end-to-end tests first."


> ### Integrating tests with build pipelines
>
> In this chapter, Ant will learn how to test an AppSync application. He'll integrate automated tests with their build pipelines to complete the test automation in the Working with deployment pipelines chapter.

------

<div style="border: 1px solid #FFE58F; background: #FFFBE6; border-radius: 4px; padding: 12px 24px; width: 100%; margin: 0 auto 20px;">
  <p>This is an excerpt from Chapter 6 of <i><a href="http://localhost:4000/running-serverless-realtime-graphql-applications-with-appsync/">Running Serverless: Realtime GraphQL applications with AppSync</a></i>, a book by Gojko Adzic, Aleksandar Simović, and Slobodan Stojanović.</p>

  <p style="margin-bottom: 0px">Here's <a href="#">a short survey</a> that will help us to polish the story. It'll take two minutes or less to fill it out. Thanks!</p>
</div>

¹ Test Pyramid, or Test Automation Pyramid, was introduced by Mike Cohn in his book Succeeding with Agile