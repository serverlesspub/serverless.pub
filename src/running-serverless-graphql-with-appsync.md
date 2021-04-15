---
layout: book-landing
seriesTitle: "Running Serverless"
seriesSubTitle: "Realtime GraphQL Applicatins with AppSync"
title: "Running Serverless: Realtime GraphQL Applicatins with AppSync"
excerpt: "New book by AWS Heroes Aleksandar Simovic, Slobodan Stojanovic and Gojko Adzic. Learn how to build and operate responsive, collaborative applications at scale with AWS AppSync and GraphQL."
feature_image: running-serverless-realtime-graphql-applications-with-appsync-cover.jpg
permalink: /running-serverless-realtime-graphql-applications-with-appsync/
---

## Book coming in Q3 2021

New book by AWS Heroes Aleksandar Simovic, Slobodan Stojanovic and Gojko Adzic. Learn how to build and operate responsive, collaborative applications at scale with AWS AppSync and GraphQL.

The book will be available in Q3 2021, subscribe below, and we'll notify you when the early release is ready.

<script async data-uid="62d5ced01c" src="https://tremendous-designer-7712.ck.page/62d5ced01c/index.js"></script>

This book will teach you how to build, test, and operate a GraphQL application using AWS AppSync and AWS Cloud Development Kit (AWS CDK).

<img class="cover" src="/img/running-serverless-realtime-graphql-applications-with-appsync-cover.jpg" alt="Running Serverless: Realtime GraphQL Applications with AppSync" />

## Table of Contents

<div id="toc" class="book-toc">
  <h3 id="part_id_1" class="sect0">Part 1: Intro</h3>

  <div class="sect1">
    <h4 id="chapter_id_1">1 Here is what we’re going to build</h4>
    <p>Quick domain intro</p>
    <p>Upollo architecture</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_2">2 AppSync in five minutes</h4>
    <p>What is AppSync?</p>
    <p>When to use AppSync?</p>
    <p>When not to use AppSync?</p>
    <p>Why GraphQL?</p>
    <p>How AppSync works with other AWS services?</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_3">3 CDK in five minutes</h4>
    <p>Infrastructure as code – literally</p>
    <p>Why CDK?</p>
    <p>CDK constructs</p>
    <p>How CDK compares to other deployment tools</p>
    <p>Setting up CDK for local development</p>
    <p>Setting up your AWS account</p>
    <p>Testing the configuration</p>
  </div>

  <h3 id="part_id_2" class="sect0">Part 2: Basic Development tasks</h3>

  <div class="sect1">
    <h4 id="chapter_id_4">4 Your first AppSync app</h4>
    <p>Hello World from CDK and AppSync</p>
    <p>Deploying an AppSync App</p>
    <p>AppSync application structure</p>
    <p>Generating API Keys</p>
    <p>Retrieving CloudFormation outputs with CDK</p>
    <p>Trying it out from the AWS console</p>
    <p>Trying it out from the command line</p>
    <p>Troubleshooting Appsync</p>
    <p>Accessing Data Sources from AppSync</p>
    <p>What are AppSync Resolvers?</p>
    <p>Troubleshooting deployments</p>
    <p>How to remove deployed applications</p>
    <p>Other Authentication options</p>
    <p>Where to find more information?</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_5">5 Building a simple GraphQL Schema</h4>
    <p>ModellingGraphQlTypes</p>
    <p>Modelling GraphqQL operations</p>
    <p>Verifying your schema</p>
    <p>VTL template basics</p>
    <p>Passing arguments using AppSync VTL context</p>
    <p>Formatting results using AppSync VTL utility functions</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_6">6 Testing AppSync applications</h4>
    <p>Simulating AppSync for local tests</p>
    <p>Automated integration - testing with AppSync</p>
    <p>Securing access using IAM</p>
    <p>Testing API access</p>
    <p>Unit testing VTL templates</p>
  </div>

  <h3 id="part_id_3" class="sect0">Part 3: Working with persistent data</h3>

  <div class="sect1">
    <h4 id="chapter_id_7">7 Connecting AppSync to DynamoDB</h4>
    <p>Scope for this chapter</p>
    <p>Why DynamoDB?</p>
    <p>Adding a database using CDK</p>
    <p>Accessing DynamoDB items using the web console</p>
    <p>Accessing DynamoDB records from the command line</p>
    <p>Reading from DynamoDB via AppSync: getSurveyById</p>
    <p>VTL templates for DynamoDB</p>
    <p>Integration testing AppSync with DynamoDb</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_8">8 Working with Mutations</h4>
    <p>Scope for this chapter</p>
    <p>Saving to DynamoDB using AppSync: createSurvey</p>
    <p>Creating unique IDs in resolvers using util.autoId</p>
    <p>Updating existing Dynamo records</p>
    <p>Using update conditionals to preventing accidental object creation</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_9">9 Single-table dynamo design</h4>
    <p>How Dynamo tables compare to SQL tables</p>
    <p>Why single tables?</p>
    <p>Modelling relations with single-table design</p>
    <p>Example Upollo records</p>
    <p>Migrating resolvers to single-table design: saving answers with createSurvey</p>
    <p>Using Dynamo batch writes for performance</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_10">10 Accessing object graphs with GraphQL</h4>
    <p>Using DynamoDB queries to list collections by prefix</p>
    <p>Accessing object graphs using GraphQl subitem queries</p>
    <p>Adding answers to getSurveyById</p>
    <p>Queries for lists: getAnswersBySurveyId</p>
    <p>Using pipeline resolvers to customise output</p>
    <p>Sharing VTL templates between resolvers: how to read ID from stash or args with util.defaultIfNull</p>
    <p>Testing hierarchical resolvers</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_11">11 Performing complex updates</h4>
    <p>Atomically updating Dynamo item fields</p>
    <p>Using DynamoDB transaction writes for consistency</p>
    <p>Processing votes: addVote</p>
    <p>Capturing timestamps using $util.time.nowISO8601</p>
  </div>

  <h3 id="part_id_4" class="sect0">Part 4: Working with web clients</h3>

  <div class="sect1">
    <h4 id="chapter_id_12">12 Introduction to AWS Amplify</h4>
    <p>Using the aws-amplify React Client</p>
    <p>Creating and deploying an Amplify App that connects to AppSync</p>
    <p>Running GraphQL queries</p>
    <p>Executing GraphQL mutations</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_13">13 Authenticating users with AWS Cognito</h4>
    <p>What is Cognito?</p>
    <p>User pools</p>
    <p>Hosted UI</p>
    <p>Allowing Cognito access in GraphQL</p>
    <p>Testing Cognito access from the AWS Web console</p>
    <p>Integrating Cognito with Amplify Apps</p>
    <p>Modelling data security using GraphQL</p>
    <p>Restricting data reads using AppSync</p>
    <p>Dealing with unauthorised access on the frontend</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_14">14 Realtime updates with GraphQl subscriptions</h4>
    <p>How GraphQl subscriptions work?</p>
    <p>Declaring Subscriptions in the schema</p>
    <p>Triggering subscriptions with mutations</p>
    <p>Subscribing to updates using Amplify SDK </p>
  </div>
  
  <h3 id="part_id_5" class="sect0">Part 5: Connecting to other services using AppSync Resolvers</h3>

  <div class="sect1">
    <h4 id="chapter_id_15">15 Using AWS Lambda for custom processing</h4>
    <p>Converting data using Lambda</p>
    <p>Connecting to other AWS Services (S3)</p>
    <p>Using Lambda logs for CloudWatch metrics</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_16">16 Searching using Elastic Search</h4>
    <p>Updating ElasticSearch documents using DynamoDB streams</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_17">17 Connecting to external APIs using HTTP resolvers</h4>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_18">18 Processingtransientdatawithlocalresolvers</h4>
    <p>Triggering custom notifications </p>
  </div>
  
  <h3 id="part_id_6" class="sect0">Part 6: Operating AppSync applications</h3>

  <div class="sect1">
    <h4 id="chapter_id_19">19 Working with deployment pipelines</h4>
    <p>Setting up for team work</p>
    <p>Deploying CDK apps using AWS CodePipeline</p>
    <p>Deploying AWS Amplify Apps</p>
    <p>Managing dev, test, staging and production stacks</p>
    <p>Configuring using SSM</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_20">20 Monitoring AppSync applications</h4>
    <p>ClodudWatch logs</p>
    <p>CloudWatch insights</p>
    <p>Adding custom metrics</p>
    <p>X Ray</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_21">21 Setting up a custom domain</h4>
    <p>Integrating AppSync APIs with CloudFront distributions</p>
    <p>Deploying to multiple regions</p>
  </div>
  
  <h3 id="part_id_7" class="sect0">Part 7: Quick reference guide</h3>

  <div class="sect1">
    <h4 id="chapter_id_22">22 GraphQL reference</h4>
    <p>Types</p>
    <p>Mutations</p>
    <p>Queries</p>
    <p>Subscriptions</p>
    <p>AppSync extensions</p>
  </div>

  <div class="sect1">
    <h4 id="chapter_id_23">23 VTL reference</h4>
    <p>Whatis VTL?</p>
    <p>Conditions</p>
    <p>Loops</p>
    <p>AppSync context</p>
    <p>AppSync Utility functions</p>
    <p>Where next?</p>
  </div>
</div>

## Subscribe and get notified

The book will be available in Q3 2021, subscribe below, and we'll notify you when the early release is ready.

<script async data-uid="62d5ced01c" src="https://tremendous-designer-7712.ck.page/62d5ced01c/index.js"></script>
