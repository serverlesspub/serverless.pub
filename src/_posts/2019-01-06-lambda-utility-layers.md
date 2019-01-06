---
layout: post
title:  "FFmpeg, SOX, Pandoc and RSVG for AWS Lambda"
excerpt: "Manipulate video, sound files, SVG images and text documents in Lambda functions, with just a few lines of code."
date: 2019-01-06 08:50:28
categories: Lambda
author_name : Gojko Adzic
author_url : /author/gojko
author_avatar: gojko.jpg
twitter_username: gojkoadzic
show_avatar: true
feature_image: lambda-layers.png
show_related_posts: false
square_related: recommend-gojko
---

You can now use all the power of FFmpeg, SOX, Pandoc and RSVG to manipulate video, sound files, SVG images and text documents in Lambda functions, with just a few lines of code. We've pre-packaged four commonly used file conversion utilities into Lambda layers, which you can use with any serverless framework or deployment utility. 

With low on-demand cost and scalability, cloud functions are ideal for file conversions. But for computationally intensive tasks, such as transcoding video, compiled code still rocks, and in most cases the best way of converting files is to just call into a standard Unix utility such as FFmpeg. The basic AWS Lambda container is quite constrained, and until recently it was relatively difficult to include additional binaries into Lambda functions. [Lambda Layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html) make that easy.

A Layer is a common piece of code that is attached to your Lambda runtime in the `/opt` directory. You can reuse it in many functions, and deploy it only once. Individual functions do not need to include the layer code in their deployment packages, which means that the resulting functions are smaller and deploy faster. For example, at [MindMup](https://www.mindmup.com), we use Pandoc to convert markdown files into Word documents. The actual lambda function code is only a few dozen lines of JavaScript, but before layers, each deployment of the function had to include the whole Pandoc binary, larger than 100 MB. With a layer, we can publish Pandoc only once, so we use significantly less overall space for Lambda function versions. Each code change now requires just a quick redeployment.

![](/img/lambda-layers.png)

And the best part of this is that you can also use Layers published by other people. Here are the four common Unix utility layers: you can build and deploy your own versions easily from Github, or just use the Layers we published directly:

* FFmpeg: `arn:aws:lambda:us-east-1:145266761615:layer:ffmpeg:4` installs `/opt/bin/ffpmeg` and `/opt/bin/ffprobe` ([Source on GitHub](https://github.com/serverlesspub/ffmpeg-aws-lambda-layer)).
* Pandoc: `arn:aws:lambda:us-east-1:145266761615:layer:pandoc:1` installs `/opt/bin/pandoc` ([Source on GitHub](https://github.com/serverlesspub/pandoc-aws-lambda-binary))
* RSVG: `arn:aws:lambda:us-east-1:145266761615:layer:rsvg-convert:2` installs `/opt/bin/rsvg-convert` ([Source on GitHub](https://github.com/serverlesspub/rsvg-convert-aws-lambda-binary))
* SOX: `arn:aws:lambda:us-east-1:145266761615:layer:sox:1` installs `/opt/bin/sox`, `/opt/bin/lame` and `/opt/bin/soxi` ([Source on GitHub](https://github.com/serverlesspub/sox-aws-lambda-binary))

The layers are published according to the original licenses from the Unix utilities, GPL2. For more information on those binaries and how to use them, check out the original project pages: <https://ffmpeg.org/>, <http://pandoc.org>, <http://sox.sourceforge.net> and <https://wiki.gnome.org/Projects/LibRsvg>.

For some nice examples of these layers in action, check out these projects:

* [Serverless Video Thumbnail Builder](https://github.com/serverlesspub/s3-lambda-ffmpeg-thumbnail-builder) using AWS SAM and FFMpeg
* [SVG to PDF converter](https://github.com/claudiajs/example-projects/tree/master/svg-to-pdf-s3-converter) using Claudia.js and RSVG
* [Markdown to DOCX converter](https://github.com/claudiajs/example-projects/tree/master/pandoc-s3-converter) using Claudia.js and Pandoc
* [Markdown to DOCX converter](https://github.com/serverlesspub/s3-lambda-pandoc-s3) using AWS SAM and Pandoc

## How to use Layers in your applications

You can easily attach these layers to your functions using CloudFormation. Just include the `Layers` property into `AWS::Lambda::Function`

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

With AWS SAM, you can also use the `AWS::Serverless::Function` resource

```yml
ConvertFileFunction:
  Type: AWS::Serverless::Function
  Properties:
    Handler: index.handler
    Runtime: nodejs8.10
    CodeUri: src/
    Layers:
      - !Ref LambdaLayerArn
```

With [`claudia`](https://claudiajs.com), use the `--layers <LambdaLayerArn>` option with `claudia create` or `claudia update` to attach a layer to a function. 

With the Serverless Framework, use the [Layers property](https://serverless.com/framework/docs/providers/aws/guide/layers/) to link a layer to your service.
