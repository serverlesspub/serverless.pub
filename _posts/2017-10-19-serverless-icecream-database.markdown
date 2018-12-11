---
layout: post
title:  "How To Create a Serverless Node.js App with DynamoDB For The First Time"
date: 2017-10-19 12:00:00 +0200
categories: Serverless DynamoDB
author_name : Aleksandar Simovic
author_url : /author/simalexan
author_avatar: simalexan
show_avatar: true
read_time: 7
feature_image: serverless-migration/figure-2.jpg
show_related_posts: false
square_related: recommend-simalexan
---

There are many articles on serverless with explained ideas, benefits and so on. Serverless is great, but articles sometimes sound more like a TV commercial.

Sometimes you just want to try and create a working example.

> Serverless is like ice cream. It’s nice to talk about it, but much better to try out.

![](/img/serverless-icecream.jpg)

The goal is to show how to create a serverless Node.js app with DynamoDB that stores and retrieves data.
Since ice creams are already mentioned, this service will be for an ice cream shop. You will save and show ice creams.

Let’s first see what do you need:

 - **a serverless host** — where you’re going to deploy and execute your code and connect to a database. We’re going with AWS, as the most mature platform at the moment.
 AWS has a serverless container service called Lambda. Because Lambda is just a compute service without “outside access”, we also need an “access point” or a “front door” service — AWS API Gateway.

 - **a development and deployment tool / library** — helps with code setup and deployment. Because serverless is still new and these tools make your life easier. Choosing a library influences the way you build your services. We’re going to use Claudia.js - a development and deployment tool with helpful examples and a good community. It will deploy your service to your AWS serverless container (Lambda) and create an API Gateway for it.

 - **a service** — your service that receives a request,  saves an ice cream to a database or shows all ice creams you saved.

 - **a database** — a storage to which you connect your service to store ice creams. We’re going with DynamoDB — AWS noSQL database.


![The overview of your service infrastructure](/img/serverless-icecream-overview.png)



## 1. Serverless host setup — AWS

You need to have an AWS account and a locally set AWS credentials file.

*If you already have both setup, scroll to section 2.*

If not, open your browser and go to — [https://console.aws.amazon.com](https://console.aws.amazon.com).

If you don’t have an AWS account, click on the button *"Create a new AWS account"* and follow the process. 

If you do, you only need to set your AWS credentials. To do it:

1. Open AWS Console, click on *"Services"* in the top navigation bar. Write IAM in the search box and click on the resulted IAM.

2. Click on “Users” on the left side menu, then “Add User”. You will see the following picture.

    ![](/img/serverless-icecream-user.png)
    There you need to type in the user name and check the programmatic access. Then click the button “Next: Permissions”.

3. You will be on the 2nd step. Now click the “Attach existing policies directly” and then check “Administrator Full Access”. Proceed to the 3rd step “Review”, and then click the “Create user” for the 4th step. 
At the last (4th) step, you will see a table with your user name and columns with your user’s “Access Key Id” and “Secret Access Key Id”. Copy those values.

4. Add those keys  to your .aws/credentials file.

    a) On OSX/*nix in — `~/.aws`

    b) On Win its  — `C:/Users/<your-user>/.aws`

    ```shell
    [default]
    aws_access_key_id = YOUR_ACCESS_KEY
    aws_secret_access_key = YOUR_ACCESS_SECRET
    ```
    Set the AWS_PROFILE environment variable to default.


## 2. Setup your development and deployment tool — Claudia.js

*If you have Claudia.js installed already scroll to section 3.*

Open your terminal and run:

`npm install -g claudia`

Claudia.js is now installed globally, available for all projects.

## 3. Write your service — Ice Cream Shop

Create your project folder (you can name it `ice-cream-shop`) and open it in your terminal. 

Initialize your Node project.

*You can do it quickly by running* `npm init -f`

Then run
```shell
 npm install aws-sdk claudia-api-builder -S 
```

This installs AWS SDK and Claudia API Builder. You need AWS SDK for accessing DynamoDB. Claudia API Builder is a helper tool with an Express-like syntax for your endpoints.

Your service needs to have two endpoints:

1. to save an icecream — needs a POST request

2.  to get all saved ice creams — needs a GET request

Now create an empty index.js file. Open it and type:

<script src="https://gist.github.com/simalexan/528f4842f4f3be3804af9512c27550a6.js"></script>

This finishes your service.

## 4. Database — setup DynamoDB

You need to create a database on AWS, but instead of using AWS Console, you can just execute one command:

```shell
aws dynamodb create-table --table-name icecreams \
  --attribute-definitions AttributeName=icecreamid,AttributeType=S \
  --key-schema AttributeName=icecreamid,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
  --region us-east-1 \
  --query TableDescription.TableArn --output text
```

This command creates a DynamoDB table named `icecreams` in the same region as our Lambda, with an key attribute `icecreamid` of String type. The command returns the table’s Amazon Resource Name (ARN) to confirm that everything is set up correctly.

### Giving your service permission for the database

The last step is allowing your service access to your DynamoDb database. To do that your service requires a permission policy. Instead of doing it via AWS Console, you can create a policy file in your project and apply it with Claudia.

Inside your ice-cream-shop project folder create a folder named `policy` and in it a file called `dynamodb-policy.json` with the following contents:

<script src="https://gist.github.com/simalexan/5e7bff9eb50cd392c715407ad1682b10.js"></script>
*If copying from here, be sure the code stays with the same spacing. JSON must keep a proper structure.*

This policy allows your Lambda service to access your DynamoDb database. When invoking Claudia to deploy your code, this policy file location needs to be passed as the command option, to let Claudia know to assign the policy to your Lambda.


It’s time for your first deployment. In the first, Claudia.js creates a Lambda for your service. So, go back to your project folder `ice-cream-shop` and run:

```shell
claudia create --region us-east-1 --api-module index --policies policy
```

This command creates your serverless container (AWS Lambda) in the `us-east-1` region, sets the `index` file as the main, and assigns the policy from the `policy` folder to your Lambda. If successful, it returns the created service URL endpoint in the command final output similar to this:

```shell
{
  "lambda": {
    "role": "ice-cream-shop-executor",
    "name": "ice-cream-shop",
    "region": "us-east-1"
  },
  "api": {
    "id": "your-service-id",
    "module": "index",
    "url": "https://your-service-url.execute-api.us-east-1.amazonaws.com/latest"
  }
}
```

That’s it! 

### Trying out your service

Use cURL for testing. Get all ice creams:

```shell
curl https://your-service-url.execute-api.us-east-1.amazonaws.com/latest/icecreams
```

Save an ice cream:

```shell
curl -H "Content-Type: application/json" -X POST \
-d '{"icecreamId":"123", "name":"chocolate"}' \
https://your-service-url.execute-api.us-east-1.amazonaws.com/latest/icecreams
```

By running these commands you’ll see your service working!

That’s it!


### Errors?
In case of an error, please check your code if you haven’t missed anything. After an error, invoking the command again may show

```shell
'Role with name ice-cream-shop-executor already exists.'
```

In that case, go to your [AWS Console IAM](https://console.aws.amazon.com/iam), in the left bar- click *“Roles”* and find a role with the name error specified and delete it. Then try the previous claudia create command again.


### Updating your service
If you want to redeploy to your Lambda with Claudia.js, now you need to do a claudia update instead of create . The full command would look like this:

`claudia update`

It doesn't need all those configuration options like `create`, because it stores them locally for you. If its successful, it also returns the URL of your deployed service.

Now go, you deserve some ice cream!


The full code example is available on [this repository](https://github.com/effortless-serverless/ice-cream-shop).