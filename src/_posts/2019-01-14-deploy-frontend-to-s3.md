---
layout: post
title:  "How to use CloudFormation to deploy Frontend Apps to S3 and Serverless Application Repository"
excerpt: "Deploy and publish Frontend SPA apps, static websites and MicroFrontends to S3 and Serverless Application Repository using CloudFormation"
date: 2019-01-14 10:00:00
categories: 
  - Serverless
  - CloudFormation
author_name : Aleksandar Simovic
author_url : /author/simalexan
author_avatar: simalexan.jpg
twitter_username: simalexan
show_avatar: true
feature_image: cloudformation-deploy-s3.jpg
show_related_posts: false
square_related: recommend-simalexan
---

If you ever wanted to do automatic deployments of frontend web applications along with CloudFormation resources, your time has arrived. We’ve created a Lambda Layer and a Custom Resource which automatically deploys frontend web apps and their files into a specified destination S3 bucket. No need to do deploy a SPA app or a static website separately from the backend, you can just do it with a standard `sam deploy` or `aws cloudformation deploy` commands.

We’ve provided it with a Python Lambda Layer which contains the `resource_handler` which  uploads the files to the Target S3 Bucket, so you don’t have to have any code whatsoever. It’s written in such a way that even if you don’t know CloudFormation at all, you’ll be able to deploy it. Additionally, we provided a Custom Resource, whose purpose is to invoke the Lambda the moment the CloudFormation Stack is created, to have the code deployed on every `sam deploy` or `cloudformation deploy` command.

## Publishing Frontend Apps to AWS Serverless Application Repository

The biggest benefit of this stack is that it allows you to publish your Frontend Applications or Components to the AWS Serverless Application Repository (SAR, from now on). Previously, it was very hard to virtually impossible to deploy any SPAs, static websites or even frontend components to SAR. Just before Re:Invent 2018, AWS announced support for CloudFormation Custom Resources, so we decided to try it out. It worked, so now you can deploy any kind of React.js, Vue.js, Angular or any kind of frontend, and combine it with your backend stacks too. Additionally, you can also combine these applications as Nested Applications, so that you can combine your frontend applications with some other published serverless applications that are available on Serverless Application Repository. Here is an example:

- Contact Form static site connected to an API to send emails

## Multi-App Deployment

A Lambda Layer are a common piece of code that you can attach to any Lambda, and they are defined only once. You can reuse it and even deploy multiple websites or SPA applications inside the same Stack as well, without needing to define a deploy command per website, you can just specify each Lambda with the appropriate Layer and its corresponding AWS Custom Resource to  deploy a certain website. That means that you can easily do MicroFrontends using just one CloudFormation stack.

## The S3 Deployment Layer

Here is the ARN of the Layer we published which is publicly available for everyone to use:

`arn:aws:lambda:us-east-1:145266761615:layer:s3-deployment:4`

The layer is published with the MIT license.

## How does it work

The whole process may seem a bit scary, as it involves both a Lambda Layer and a Custom Resource, which you might not be familiar with, but its actually quite simple.

We want our frontend files to be uploaded to S3. S3 doesn't accept files as its contents, so we are going to use a Lambda Function which is able to load files into it. Therefore we put the files inside a folder, and the Lambda Function needs to reference this folder as its CodeUri, in order to load them. Now, the Lambda also needs to reference our S3 Deployement Lambda Layer, as its supposed to use its the `deployer.py` method called `resource_handler` as the function Handler, which will load the files within a Lambda into your S3 Bucket. That means when the Lambda is invoked it will run the `deployer.resource_handler` and the Layer handler will have access to your folder files specifed with the `CodeUri`.

Now it only needs to be invoked whenever we do a deploy our CloudFormation stack.

To achieve that we are using a AWS CustomResource which invokes a Function by its ARN specified in its `ServiceToken` property. We also need to specify the Bucket where we want to send the files to, what kind of Access Control List we want too and to pass a `Version` parameter to redeploy each time we deploy. If we didn't specify it, it wouldn't redeploy if the files are already there, despite them being different. But the Lambda version is always the same when you initially deploy, so we then need to add the `AutoPublishAlias: live` on the Lambda in order to get the generated deploy version, to enable the Custom Resource to wake up and invoke the function each time the stack is deployed. You can see this flow in the following figure.

![](/img/cloudformation-deploy-to-s3-figure.png)

## How to use this in your web application

1. Define a new CloudFormation template and add AWS Serverless Transformation

```yml
AWSTemplateFormatVersion: 2010-09-09
Transform: 'AWS::Serverless-2016-10-31'

Resources:
```

2. Add a Serverless Function Resource, call it `SiteSource` and add as its `Properties` the aforementioned `Layer`, `CodeUri` pointing to a folder inside the project (for example `web-site`), containing the frontend files, set the `Runtime` to `python3.6` and the `Handler` pointing to `deployer.resource_handler`.

```yml
SiteSource:
  Type: AWS::Serverless::Function
  Properties:
    Layers:
      - arn:aws:lambda:us-east-1:145266761615:layer:s3-deployment:4
    CodeUri: web-site/
    Runtime: python3.6 
    Handler: deployer.resource_handler
```

3. Set the Properties `Timeout` to `600` (10 minutes, as we want to be sure in case our website is too big or our network is bit slow) and also add `Policies` to the Properties too. In the Policies, specify `S3FullAccessPolicy` with a parameter `BucketName` referencing the defined `TargetBucket` S3 resource. Also add  an `AutoPublishAlias` with the value of `live`. This will generate a new version of the Lambda and make it available as a retrievable property on every CloudFormation deployment.

```yml
SiteSource:
  Type: AWS::Serverless::Function
  Properties:
    Layers:
      - arn:aws:lambda:us-east-1:145266761615:layer:s3-deployment:4
    CodeUri: web-site/
    AutoPublishAlias: live
    Runtime: python3.6 
    Handler: deployer.resource_handler
    Timeout: 600
    Policies:
      - S3FullAccessPolicy:
          BucketName: !Ref TargetBucket
```

4. Define an AWS::CloudFormation::CustomResource with a name `DeploymentResource`. Set its `Properties` to have:
- a `ServiceToken` which takes the `Arn` attribute from the `SiteSource` Serverless Function,
- a `Version` property referencing a string variable `"SiteSource.Version”`,
- a `TargetBucket` property referencing a the `TargetBucket` S3 resource,
- property `Acl` set to `public-read` (if you want it to be publicly visible from the browser, otherwise set it to `private`) and,
- the `CacheControlMaxAge` set to 600.

```yml
DeploymentResource:
  Type: AWS::CloudFormation::CustomResource
  Properties:
    ServiceToken: !GetAtt SiteSource.Arn
    Version: !Ref "SiteSource.Version"
    TargetBucket: !Ref TargetBucket
    Acl: 'public-read'
    CacheControlMaxAge: 600
```

5. Add an S3 Bucket Resource in the template, you can call it `TargetBucket`

```yml
TargetBucket:
  Type: AWS::S3::Bucket
```

If you wanted to see it whole, here is the complete code preview:

```yml
AWSTemplateFormatVersion: 2010-09-09
Transform: 'AWS::Serverless-2016-10-31'

Resources:
  TargetBucket:
    Type: AWS::S3::Bucket
  SiteSource:
    Type: AWS::Serverless::Function
    Properties:
      Layers:
        - arn:aws:lambda:us-east-1:145266761615:layer:s3-deployment:4
      CodeUri: web-site/
      AutoPublishAlias: live
      Runtime: python3.6 
      Handler: deployer.resource_handler
      Timeout: 600
      Policies:
        - S3FullAccessPolicy:
            BucketName: !Ref TargetBucket
  DeploymentResource:
    Type: AWS::CloudFormation::CustomResource
    Properties:
      ServiceToken: !GetAtt SiteSource.Arn
      Version: !Ref "SiteSource.Version"
      TargetBucket: !Ref TargetBucket
      Acl: 'public-read'
      CacheControlMaxAge: 600
```

You can also see this example in the Github repository `/example` folder by clicking [here](https://github.com/serverlesspub/cloudformation-deploy-to-s3/blob/master/example).

Now just run:
`aws cloudformation package --template-file <template-file-location> --output-template-file <output-template-file-location> --s3-bucket=<cloudformation-bucket-name>`
and then run
`aws cloudformation deploy --template-file  <template-file-location> --stack-name <stack-name> --capabilities CAPABILITY_IAM`