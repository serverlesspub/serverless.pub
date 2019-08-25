---
layout: post
title:  "Publishing Lambda Layers using SAR"
excerpt: "Semantic versioning, region replication and account permissions for Lambda layers"
date: 2019-08-25 00:00:00
categories: 
  - Serverless
  - CloudFormation
author_name : Gojko Adzic
author_url : /author/gojko
author_avatar: gojko.jpg
twitter_username: gojkoadzic
show_avatar: true
feature_image: layer-app-repo.png 
show_related_posts: false
square_related: recommend-gojko
---

Lambda Layers are a convenient tool to share dependencies across Lambda functions. Many organisations publish utility layers for extending basic Lambda runtimes with tools such as monitoring or logging, but bare-bones layer publishing is problematic for several reasons. First, the layer versions are just incremental numeric sequences, so it's difficult to know if an update is backwards compatible or not. The second issue is that linking a layer deployed by a third-party organisation effectively binds your code to something outside your control. The third big issue is that linking layers across AWS regions just doesn't work. All these drawbacks can be solved very easily by publishing a layer through the Serverless Application Repository.

## Publishing layers to SAR

The Serverless Application Repository is, as usual for AWS, a bit misnamed. The name suggests that people can find applications in that repository, but it's effectively a public CloudFormation template store. You can publish many things to it, not just applications (whatever that means in the serverless ecosystem). For this particular topic, it's important to know that you can publish a CloudFormation template containing just a Lambda Layer. There are several benefits of publishing a layer to SAR instead of directly making it available to other accounts:

* SAR applications support semantic versioning, so you can signal major, minor and patch releases to clients
* SAR applications are deployed to client accounts, so someone linking a SAR application will effectively create a copy in their own AWS account instead of depending on some third-party service availability
* It's easy to make SAR applications private, share them with individual AWS accounts or make them public and accessible to everyone
* Public SAR applications are automatically replicated across all regions, so someone can just publish a layer in a single place and clients from all AWS regions can use it easily
* The [SAR web portal](https://serverlessrepo.aws.amazon.com/applications/) provides a way to discover published applications easily

To publish a layer to SAR, you'll need a CloudFormation template that provides a `Metadata` section, with an `AWS::ServerlessRepo::Application` resource describing the thing you are publishing. Make sure to include the layer reference in the template outputs, so clients installing this application can use it. 

Here is a simple example, from the [ImageMagick layer](https://github.com/serverlesspub/imagemagick-aws-lambda-2) compatible with AWS Linux 2.


```yaml
AWSTemplateFormatVersion: 2010-09-09
Transform: AWS::Serverless-2016-10-31
Description: >
  Static build of ImageMagick for Amazon Linux 2,
Resources:
  ImageMagickLayer:
    Type: AWS::Serverless::LayerVersion
    Properties:
      LayerName: image-magick
      Description: Static build of ImageMagick for AWS Linux 2,
      ContentUri: build/layer.zip
      CompatibleRuntimes:
        - nodejs10.x
      LicenseInfo: https://imagemagick.org/script/license.php
      RetentionPolicy: Retain

Outputs:
  LayerVersion:
    Description: Layer ARN Reference
    Value: !Ref ImageMagickLayer

Metadata:
  AWS::ServerlessRepo::Application:
    Name: image-magick-lambda-layer
    Description: >
      Static build of ImageMagick for Amazon Linux 2,
    Author: Gojko Adzic
    SpdxLicenseId: ImageMagick
    LicenseUrl: LICENSE.txt
    ReadmeUrl: README-SAR.md 
    Labels: ['layer', 'image', 'lambda', 'imagemagick']
    HomePageUrl: https://github.com/serverlesspub/imagemagick-aws-lambda-2
    SemanticVersion: 1.0.0
    SourceCodeUrl: https://github.com/serverlesspub/imagemagick-aws-lambda-2
```

For more information on the metadata section, check out the [AWS SAM Template Metadata Section Properties](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-template-publishing-applications-metadata-properties.html).

With this template, using the SAM command-line tools, you can just run `sam publish` after `sam package` and the application will be uploaded to SAR. Note that the uploaded application is private by default, you can make it public and accessible to other AWS accounts using the following command line:

```
aws serverlessrepo put-application-policy 
  --application-id <APP_ARN>
  --statements Principals='*',Actions=Deploy
```

## How to use layers in your applications


Using SAM, you can deploy the layer and a function from the same template, by including a resource of type `AWS::Serverless::Application`, and pointing to the application ARN and semantic version in the `Location` field. Because applications are just CloudFormation templates, you can read out any outputs directly from the `Outputs` property of the resulting resource. Here is a quick snippet that includes the ImageMagick layer as an application:

```yaml
Resources:
  ImageMagick:
    Type: AWS::Serverless::Application
    Properties:
      Location:
        ApplicationId: arn:aws:serverlessrepo:us-east-1:145266761615:applications/image-magick-lambda-layer
        SemanticVersion: 1.0.0
  ConvertFileFunction:
    Type: AWS::Serverless::Function
    Properties:
      CodeUri: image-conversion/
      Handler: index.handler
      Runtime: nodejs10.x
      Layers:
        - !GetAtt ImageMagick.Outputs.LayerVersion
```

For some nice examples of layers you can install this way, check out the [layers we published for many common Linux file conversion utilities](https://serverless.pub/lambda-utility-layers/).

For more detailed examples and a walk-through, check out my book [Running Serverless](https://runningserverless.com).
