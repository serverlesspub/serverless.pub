---
layout: post
title:  "FFmpeg, ImageMagick, Pandoc and RSVG for AWS Lambda"
excerpt: "Manipulate video, sound files, SVG images and text documents in Lambda functions, with just a few lines of code."
date: 2019-06-20 00:00:00
categories: 
  - Serverless
  - CloudFormation
author_name : Gojko Adzic
author_url : /author/gojko
author_avatar: gojko.jpg
twitter_username: gojkoadzic
show_avatar: true
feature_image: lambda-layers.png
show_related_posts: false
square_related: recommend-gojko
---

**Update: 20 June 2019 - new versions of layers for Amazon Linux 2, all layers published to SAR**

Lambda runtimes based on Amazon Linux 2 come without almost any system libraries and utilities. Using the additional layers listed in this post, you can add FFmpeg, ImageMagick, Pandoc and RSVG to your Lambda environments, and manipulate video, sound files, images and text documents in Lambda functions, with just a few lines of code. The layers are compatible with Amazon Linux 1 and Amazon Linux 2 instances (including the nodejs10.x runtime, and the updated 2018.03 Amazon Linux 1 runtimes).

A [Lambda Layer](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html) is a common piece of code that is attached to your Lambda runtime in the `/opt` directory. You can reuse it in many functions, and deploy it only once. Individual functions do not need to include the layer code in their deployment packages, which means that the resulting functions are smaller and deploy faster. 

![](/img/lambda-layers.png)

We published these layers to the AWS Serverless Application Repository, so you can install them with a single click into your AWS account. For manual deployments and to configure versions, check out the individual GitHub repositories. 

* `image-magick-lambda-layer`: installs `/opt/bin/convert`, `/opt/bin/mogrify` and similar tools 
  * ARN: `arn:aws:serverlessrepo:us-east-1:145266761615:applications/image-magick-lambda-layer`
  * [App link](https://serverlessrepo.aws.amazon.com/applications/arn:aws:serverlessrepo:us-east-1:145266761615:applications~image-magick-lambda-layer)
  * [Source/Manual deployment](https://github.com/serverlesspub/imagemagick-aws-lambda-2)
* `ffmpeg-lambda-layer`: installs `/opt/bin/ffpmeg` and `/opt/bin/ffprobe`
  * ARN: `arn:aws:serverlessrepo:us-east-1:145266761615:applications/ffmpeg-lambda-layer`
  * [App link](https://serverlessrepo.aws.amazon.com/applications/arn:aws:serverlessrepo:us-east-1:145266761615:applications~ffmpeg-lambda-layer)
  * [Source/Manual deployment](https://github.com/serverlesspub/ffmpeg-aws-lambda-layer)
* `pandoc-lambda-layer`: installs `/opt/bin/pandoc` 
  * ARN: `arn:aws:serverlessrepo:us-east-1:145266761615:applications/pandoc-lambda-layer`
  * [App link](https://serverlessrepo.aws.amazon.com/applications/arn:aws:serverlessrepo:us-east-1:145266761615:applications~pandoc-lambda-layer)   
  * [Source/Manual deployment](https://github.com/serverlesspub/pandoc-aws-lambda-binary)
* `rsvg-convert-lambda-layer`: installs `/opt/bin/rsvg-convert` 
  * ARN: `arn:aws:serverlessrepo:us-east-1:145266761615:applications/rsvg-convert-lambda-layer`
  * [App link](https://serverlessrepo.aws.amazon.com/applications/arn:aws:serverlessrepo:us-east-1:145266761615:applications~rsvg-convert-lambda-layer)
  * [Source/Manual deployment](https://github.com/serverlesspub/rsvg-convert-aws-lambda-binary)


The layers are published according to the original licenses from the Unix utilities, GPL2 or later. For more information on those binaries and how to use them, check out the original project pages: <https://ffmpeg.org/>, <http://pandoc.org>, <https://imagemagick.org> and <https://wiki.gnome.org/Projects/LibRsvg>.

## How to use layers in your applications

Click on individual GitHub repository links to see example usage code in action. Here are a few code snippets for quick access:

Using SAM, you can deploy the layer and a function from the same template:

```yaml
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

Without SAM, deploy a layer using the application links above, then just include the `Layers` property into `AWS::Lambda::Function`

```yml
ConvertFileFunction:
  Type: AWS::Lambda::Function
  Properties:
    Handler: index.handler
    Runtime: nodejs8.10
    CodeUri: src/
    Layers:
      - !Ref LambdaLayerArn
```

With [`claudia`](https://claudiajs.com), use the `--layers <LambdaLayerArn>` option with `claudia create` or `claudia update` to attach a layer to a function. 

With the Serverless Framework, use the [Layers property](https://serverless.com/framework/docs/providers/aws/guide/layers/) to link a layer to your service.


