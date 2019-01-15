---
layout: post
title:  "How to use CloudFormation to deploy Frontend Apps to S3 and Serverless Application Repository"
excerpt: "Deploy and publish Frontend SPA apps, UI components, static websites and MicroFrontends to S3 and Serverless Application Repository using CloudFormation"
date: 2019-01-13 20:00:00
categories: 
  - Serverless
  - CloudFormation
  - S3
  - Frontend
author_name : Aleksandar Simovic
author_url : /author/simalexan
author_avatar: simalexan.jpg
twitter_username: simalexan
show_avatar: true
feature_image: s3-deployment-diagram.png
show_related_posts: false
square_related: recommend-simalexan
---

If you ever wanted to do automatic deployments of frontend web applications along with CloudFormation resources, your time has come. We’ve created a Lambda Layer and a Custom Resource which automatically deploys frontend web apps and their files into a S3 bucket. No need to do deploy a SPA app or a static website separately from the backend, you can just do it with a standard `sam deploy` or `aws cloudformation deploy` commands.

We opensourced a Python Lambda Layer that will handle the uploads of your files to the S3 bucket, so you don’t have to write any additional code. The layer is easy to use in SAM and Cloudformation templates, even for beginners. We also published an example project that demonstrates how to package and deploy web site code using the layer and a Cloudformation Custom Resource.

The deployment layer is available under the MIT license. You can get the source code from the GitHub [repository](https://github.com/serverlesspub/cloudformation-deploy-to-s3) and deploy to your account, or just use the public version available from the following ARN:

`arn:aws:lambda:us-east-1:145266761615:layer:s3-deployment:4`

## How it works

We want our frontend files to be uploaded to S3. The standard S3 resources in CloudFormation are used only to create and configure buckets, so you can't use them to upload files. So, we use the web site assets directory as the source for a Lambda function, and CloudFormation will package them. Now, the Lambda also needs to reference our S3 Deployement Lambda Layer, as its supposed to use its the `deployer.py` method called `resource_handler` as the function Handler, which will load the files within a Lambda into your S3 Bucket. That means when the Lambda is invoked it will run the `deployer.resource_handler` and the Layer handler will have access to your folder files specifed with the `CodeUri`.

Now it only needs to be invoked whenever we do a deploy our CloudFormation stack.

To achieve that we are using a Custom Resource which invokes a Function by its ARN specified in its `ServiceToken` property. We also need to specify the Bucket where we want to send the files to, what kind of Access Control List we want too and to pass a `Version` parameter to redeploy each time we deploy. Cloudformation usually updates custom resources only when their parameters change, not when the underlying Lambda function changes. Because we're using the web site assets as the source of the Lambda function, we need to additionally ensure that any changes to those assets automatically trigger the update. To do that, we'll make SAM deploy a new version with each update of the Lambda code (site assets), and add that version as the parameter of the custom resource. But the Lambda version is always the same when you initially deploy, so we then need to add the `AutoPublishAlias: live` on the Lambda in order to get the generated deploy version, to enable the Custom Resource to wake up and invoke the function each time the stack is deployed. You can see this flow in the following figure.

![Deploy static assets to S3 using CloudFormation](/img/s3-deployment-diagram.png)

## How to use this in your web application

Define a new CloudFormation template and add AWS Serverless Transformation

```yml
AWSTemplateFormatVersion: 2010-09-09
Transform: 'AWS::Serverless-2016-10-31'

Resources:
```

Add a Serverless Function Resource, call it `SiteSource` and add as its `Properties`:

- the `Layer` property pointing to the `s3-deployment` layer ARN,
- `CodeUri`, pointing to a folder inside the project (for example `web-site`), containing the frontend files,
- set the `Runtime` to `python3.6`, because the layer is using it, and,
- set the `Handler` pointing to `deployer.resource_handler`.

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

Now additional `Properties` are:

- the `Timeout` set to `600` (10 minutes, as we want to be sure in case our website is too big or our network is bit slow),
- add `Policies` to the Properties too. In the Policies, specify `S3FullAccessPolicy` with a parameter `BucketName` referencing the target bucket for uploads.
- Set an `AutoPublishAlias` with the value of `live`. This will generate a new version of the Lambda and make it available as a retrievable property on every CloudFormation deployment.

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

Define a AWS::CloudFormation::CustomResource with a name `DeploymentResource`. Set its `Properties` to have:

- a `ServiceToken` which takes the `Arn` attribute from the `SiteSource` Serverless Function,
- a `Version` property referencing a string variable `"SiteSource.Version”`,
- a `TargetBucket` property referencing a the target bucket,
- property `Acl` set to a [pre-canned S3 access policy](https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html#canned-acl). For example, `public-read` for publicly accessible web sites and,
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

Add an S3 Bucket Resource in the template, you can call it `TargetBucket`

```yml
TargetBucket:
  Type: AWS::S3::Bucket
```

Here is the complete code:

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

## Publishing Frontend Apps to AWS Serverless Application Repository

The biggest benefit of this stack is that it allows you to publish your frontend applications or components to the AWS Serverless Application Repository (SAR, from now on). Previously, it was very hard to deploy any SPAs, static websites or even frontend components to SAR. Just before Re:Invent 2018, AWS announced support for CloudFormation Custom Resources, allowing you to extend Cloudformation. Using that, our stack allows you to deploy any kind of React.js, Vue.js, Angular or any kind of frontend, and combine it with your backend stacks too. Additionally, using them as Nested Applications, you can combine them with other published serverless applications that are available on Serverless Application Repository.

You can also see this example in the Github repository `/example` folder by clicking [here](https://github.com/serverlesspub/cloudformation-deploy-to-s3/blob/master/example).

You can just use the usual SAM or Cloudformation deployment commands to create this stack on AWS.
