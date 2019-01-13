---
layout: post
title:  "How to use CloudFormation to deploy your frontend apps to S3"
excerpt: "Deploy your Frontend SPA apps, static websites and MicroFrontends to S3 using CloudFormation"
date: 2019-01-14 10:00:00
categories: 
  - Serverless
  - CloudFormation
  - SAM
  - S3
  - Frontend
  - Deployment
  - SPA
  - Static Website
  - Custom Resource
author_name : Aleksandar Simovic
author_url : /author/simalexan
author_avatar: simalexan.jpg
twitter_username: simalexan
show_avatar: true
feature_image: cloudformation-deploy-s3.jpg
show_related_posts: false
square_related: recommend-simalexan
---

If you ever wanted to do automatic deployments of your frontend web applications along with your CloudFormation resources, your time has arrived. We’ve created a Lambda Layer and a Custom Resource which automatically deploys your frontend web apps and their files into your destined S3 bucket upon every deployment. No need to do deploy your SPA app or your static website separately from your backend, you can just do it with your standard `sam deploy` or `aws cloudformation deploy` commands. Or if you had that, you might have had to define an another Lambda along with its code to deploy your frontend application whenever you invoke it.

We’ve provided it with a Python Lambda Layer which contains `the resource_handler` for  uploading the files to your Target S3 Bucket, so you don’t have to have any code to be able to deploy. It’s written in such a way that even if you don’t know CloudFormation you’ll be able to deploy it. Also ,we provided a Custom Resource, which invokes your Lambda the moment the CloudFormation Stack is created, meaning that your code gets deployed on every `sam` or `cloudformation`  deployment command.

## Multi-App Deployment

A Lambda Layer are a common piece of code that you can attach to any Lambda, and they are defined only once. You can reuse it and even deploy multiple websites or SPA applications inside the same Stack as well, without needing to define a deployment command per website, you can just specify each Lambda with the appropriate Layer and its corresponding AWS Custom Resource to  deploy a certain website. That means that you can easily do MicroFrontends using just one CloudFormation stack.

## The S3 Deployment Layer

Here is the ARN of the S3 Deployment Layer we published which is publicly available for everyone to use:

`arn:aws:lambda:us-east-1:145266761615:layer:s3-deployment:4`

The layer is published with the MIT license.

For some nice examples of this S3 Deployment Layer along with the Custom Resource, check out the examples folder within the Github repository.

## How to use this in your web application

1. Define a new CloudFormation template and add AWS Serverless Transformation

```yml
AWSTemplateFormatVersion: 2010-09-09
Transform: 'AWS::Serverless-2016-10-31'

Resources:
```

2. Add an S3 Bucket Resource in the template, you can call it `TargetBucket`

```yml
TargetBucket:
  Type: AWS::S3::Bucket
```

3. Add a Serverless Function Resource, call it `SiteSource` and add as its `Properties` the aforementioned `Layer`, `CodeUri` pointing to a folder inside your project (for example `web-site`), containing your frontend files, set the `Runtime` to `python3.6` and the `Handler` pointing to `deployer.resource_handler`.

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

4. Set the Properties `Timeout` to `600` (10 minutes, as we want to be sure in case our website is too big or our network is bit slow) and also add `Policies` to the Properties too. In the Policies, specify `S3FullAccessPolicy` with a parameter `BucketName` referencing your defined `TargetBucket` S3 resource. Also add  an `AutoPublishAlias` with the value of `live`. This will generate a new version of the Lambda and make it available as a retrievable property on every CloudFormation deployment.

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

5. Define an AWS::CloudFormation::CustomResource with a name `DeploymentResource`. Set its `Properties` to have:
- a `ServiceToken` which takes the `Arn` attribute from your `SiteSource` Serverless Function,
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

Now just run:
`aws cloudformation package --template-file <your-template-file-location> --output-template-file <your-output-template-file-location> --s3-bucket=<cloudformation-bucket-name>`
and then run
`aws cloudformation deploy --template-file  <your-template-file-location> --stack-name <your-stack-name> --capabilities CAPABILITY_IAM`