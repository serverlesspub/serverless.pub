---
layout: post
title:  "From Express.js to AWS Lambda: Migrating existing Node.js applications to serverless"
date:   2018-03-29 12:00:00 +0200
categories: serverless claudia migration
author: slobodan
image: https://effortless-serverless.com/images/serverless-migration/figure-2.jpg
---

Serverless architecture makes some of the good practices for architecturing apps obsolete. Building a serverless application from scratch requires a mind shift, but once you start thinking in a serverless way, all the dots connect quickly. With the help of tools such as Claudia.js, development and deployment cycles are short and easy.

But most of the time you can't just start from scratch. Instead, you have an app with a few thousand lines of code and a couple of thousand daily active users, with a history of questionable decisions caused by business requests or other issues that shaped your code in a specific way.

Can you and should you migrate such an application to serverless? The answer is not a simple one, because it depends on the specifics of your application, the structure of your team, and many other things. But in most cases, serverless can be beneficial for legacy applications.

Let's say you are working on a nice and simple Node.js application. For example, an app similar to [Vacation Tracker bot](http://vacationtrackerbot.com), a simple Slack tool for managing team vacations.

![Vacation tracker flow](/images/serverless-migration/figure-0.jpg)

The app itself is simple. Most of the communication goes through Slack, but there's also a nice web dashboard. As you are building MVP, you don't want to spend too much resources on it, so you spin up a new Digital Ocean instance and bundle everything inside it. At that point, as shown in the figure below, your app consists of the following:

- Ubuntu droplet with nginx
- Express.js app that serves static pages (SPA dashboard) and an API
- MongoDB database
- Cronjob that sends scheduled messages

![Simple Express.js and MongoDB app](/images/serverless-migration/figure-1.jpg)

But sometimes your app has a big spikes in usage, and you need to think about scaling. Not to mention that you need many other things such as monitoring, SSL, development and production environments, etc.

With first users, your fun side project quickly became another thing you need to maintain and configure for hours. An it costs more and more, even though users are still not paying for it. Not fun at all.

You heard about serverless and decided to give it a try. But how can you transform your traditional Node.js app to serverless? Should you just fit everything into AWS Lambda?

> In case you are not familiar with serverless, or you still think it's some magic that runs web apps by hamster wheels instead of servers, see [this explanation](https://livebook.manning.com/#!/book/serverless-apps-with-node-and-claudiajs/chapter-1).

## Divide and conquer

Although fitting everything into AWS Lambda would technically make your app serverless and it might be a good first step, to gain full benefits of serverless you'll need to put a bit more effort and embrace the serverless platform by dividing your app into small services.

Before we see how, what are the benefits you could gain?

Some of the most important benefits are:

- Your app will autoscale. And it'll do that fast, from 0 to 1000 parallel users in less than a few seconds.
- You'll pay only if someone is using your app. Zero users cost you $0. As amount of users increases,  the cost increases a bit too. For example, MindMup pays $100 a month for 400,000 monthly active users, impressive, isn't it? Read more about it [here](https://livebook.manning.com/#!/book/serverless-apps-with-node-and-claudiajs/chapter-15). 
- Having as many environments similar to production doesn't cost you anything if no-one is using them. Running experiments and tests is easier and cheaper than ever before.
- Faster development and deployment cycles, because your app is divided into smaller units and even a frontend developer that has almost non backend experience can deploy a production-ready app.

How do you do that? Simple (but sometimes not easy).

You can start by moving your single page app and static content to AWS S3. Yes, the same S3 you are using for storing files. If you combine it with AWS CloudFront, you'll get a powerful serverless static web site hosting with SSL and cache. You can configure your static website [manually](https://www.josephecombs.com/2018/03/05/how-to-make-an-AWS-S3-static-website-with-ssl) or by using a tool such as [Scotty.js](https://github.com/stojanovic/scottyjs).

Next step is to move database outside of your Digital Ocean droplet. If you want to keep MongoDB as a database, you can move it to MongoDB Atlas, a cloud-hosted MongoDB service engineered and run by the same team that builds the MongoDB database. Other, probably better option would be to migrate your content to AWS DynamoDB database, which is a serverless noSQL database offered by Amazon Web Services.

Now that your static files and database are out of the game, you can start by pulling other services out of your Express.js app. For example, scheduled messages (weekly team vacation notifications) are a good first candidate. As you can't run a cronjob in AWS Lambda, you'll need a help from another service: CloudWatch Events can trigger your Lambda function at the scheduled time, as described [here](https://medium.freecodecamp.org/scheduling-slack-messages-using-aws-lambda-e56a8eb22818).

Finally, you'll have to migrate your API. To do so, you can split your logic into multiple AWS Lambda functions and put the API Gateway in front of them, because Lambda functions can't be triggered by HTTP request directly. How should you split your API? That depends on your use case, but the easiest way is to split it by into business logic units. For example, one Lambda funciton witll work with Slack slash commands, another one will handle Slack Events webhooks, some other function or functions will serve the dashboard API. As you have some Node.js experience, you can easily create, deploy and manage web APIs using [Claudia.js](https://claudiajs.com).

As some of your API endpoints will require auth (either direct or via social login), you can replace a tool such as passport.js with AWS serverless auth service Cognito. With Cognito, requests without valid authorization will never trigger your Lambda function, so you'll pay less.

After migration, your app could look like this:

![Serverless app](/images/serverless-migration/figure-2.jpg)

## Next steps

Many teams are already using serverless it in production and, according to  [recent survey of AWS customers published by Cloudability](http://www.zdnet.com/article/serverless-computing-containers-see-triple-digit-quarterly-growth-among-cloud-users/) serverless adoption grew almost 700% in a year.

If you want to learn more each about building and migrating serverless applications, and each of the services mentioned above, [Aleksandar Simović](https://twitter.com/simalexan) and I wrote a whole book about these topics for Manning Publications. You can get the book and read the free chapters here:

[https://www.manning.com/books/serverless-apps-with-node-and-claudiajs](https://www.manning.com/books/serverless-apps-with-node-and-claudiajs)

Book will also tell you more about how other teams are using serverless in production. For example, to read more about how MindMup serves 400,000 monthly active users with two-person team and $100 AWS bill, or how a small team of CodePen frontend developers serves 200,000 requests per hour using AWS Lambda, jump to the case studies chapter directly [here](https://livebook.manning.com/#!/book/serverless-apps-with-node-and-claudiajs/chapter-15).