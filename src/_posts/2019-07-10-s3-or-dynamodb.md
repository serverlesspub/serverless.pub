---
layout: post
title:  "S3 or DynamoDB?"
excerpt: "How to choose the right storage system for AWS Lambda functions"
date: 2019-07-10 00:00:00
categories: 
  - Serverless
author_name : Gojko Adzic
author_url : /author/gojko
author_avatar: gojko.jpg
twitter_username: gojkoadzic
show_avatar: true
feature_image: s3dynamohead.png
show_related_posts: false
square_related: recommend-gojko
---

<div style="border: 1px dashed black; border-radius: 5px; padding: 5px; width: 80%; font-size:1.5rem; margin: auto;">
This is an excerpt from <i><a href="https://runningserverless.com">Running Serverless: Introduction to AWS Lambda and the Serverless Application model</a></i>, a book by <a href="https://gojko.net">Gojko Adzic</a> now available from <a href="https://amzn.to/30ilMm2">Amazon</a>, <a href="https://www.barnesandnoble.com/w/running-serverless-gojko-adzic/1132362694?ean=9780993088155">Barnes and Noble</a> and other major stores. You can get the PDF, eBook and Kindle
from <a href="https://leanpub.com/running-serverless/">LeanPub</a>, as well as more specific versions from
the <a href="https://amzn.to/2Fmtnbs">Kindle</a>, <a href="https://books.apple.com/us/book/running-serverless-introduction-to-aws-lambda-serverless/id1471835645">Apple Books</a>, <a href="https://www.kobo.com/ww/en/ebook/running-serverless-introduction-to-aws-lambda-and-the-serverless-application-model">Kobo</a>, and <a href="https://www.barnesandnoble.com/w/running-serverless-gojko-adzic/1132362694?ean=9780993088155">Nook</a> stores.
</div>

![](/img/s3dynamohead.png)

AWS Lambda instances have a local file system you can write to, connected to the system's temporary path. Anything stored there is only accessible to that particular container, and it will be lost once the instance is stopped. This might be useful for temporarily caching results, but not for persistent storage. For long-term persistence, you'll need to move the data outside the Lambda container.

## Cloud storage options 

There are three main choices for persistent storage in the cloud:

* Network file systems
* Relational databases
* Key-value stores

Network file systems are generally not a good choice for Lambda functions, for two reasons. The first is that attaching an external file system volume takes a significant amount of time. Anything that slows down initialisation is a big issue with automatic scaling, because it can amplify problems with cold starts and request latency. The second issue is that very few network storage systems can cope with potentially thousands of concurrent users, so we'd have to severely limit concurrency for Lambda functions to use network file systems without overloading them. The most popular external file storage on AWS is the Elastic Block Store (EBS), which can't even be attached to two containers at once. 

Relational databases are good when you need to store data for flexible queries, but you pay for that flexibility with higher operational costs. Most relational database types are designed for persistent connections and introduce an initial handshake between the database service and user code to establish a connection. This initialisation can create problems with latency and cold starts, similar to what happens with network file systems. AWS now offers some relational databases on a pay-per-connection basis (for example [AWS Aurora Serverless](https://aws.amazon.com/rds/aurora/serverless/)), but in general with relational databases you have to plan for capacity and reserve it up front, which is completely opposite to what we're trying to do with Lambda. Supporting a very high number of concurrent requests usually requires a lot of processing power, which gets quite expensive. Running relational databases on AWS often means setting up a virtual private cloud (VPC); attaching a VPC to Lambda still takes a few seconds, making the cold start issue even worse. 

This leaves key-value stores as the most frequent choice for persistence for Lambda functions. Key-value stores are generally optimised for writing and retrieving objects by a primary key, not for ad-hoc queries on groups of objects. Because the data is segmented, not interlinked, key-value stores are a lot less computationally demanding than relational databases, and their work can be parallelised and scaled much more easily. AWS offers several types of key-value store that work well with Lambda. The two major choices in this category are Simple Storage Service (S3) and DynamoDB. 



## Key feature differences

Both S3 and DynamoDB require no initialisation handshakes to establish a connection, they can scale on demand, so Lambda spikes will not overload them, and AWS charges actual utilisation for them, priced per request. Actually, users can choose whether they want to pay for DynamoDB based on reserved capacity or on demand. Even in reserved capacity mode it's relatively easy to add or remove writer or reader units according to short-term traffic patterns, so you don't have to worry about running out of capacity.

S3 is an _object store_, designed for large binary unstructured data. It can store individual objects up to 5 TB. The objects are aggregated into _buckets_. A bucket is like a namespace or a database table, or, if you prefer a file system analogy, it is like a disk drive. Buckets are always located in a particular region. You can easily set up [_cross-region replication_](https://docs.aws.amazon.com/AmazonS3/latest/dev/crr.html) for faster local access or backups. However, generally it's best if one region is the reference data source, because multi-master replication with S3 is not easy to set up.

DynamoDB is a _document database_, or, if you like buzzwords, a NoSQL database. Although it can keep binary objects as well, it's really designed for storing structured textual (JSON) data, supporting individual items up to 400 KB. DynamoDB stores items in _tables_, which can either be in a particular region or globally replicated. DynamoDB [Global Tables](https://aws.amazon.com/dynamodb/global-tables/) supports multi-master replication, so clients can write into the same table or even the same item from multiple regions at the same time, with local access latency.

S3 is designed for throughput, not necessarily predictable (or very low) latency. It can easily deal with bursts in traffic requests, especially if the requests are for different items. 

DynamoDB is designed for low latency and sustained usage patterns. If the average item is relatively small, especially if items are less than 4KB, DynamoDB is significantly faster than S3 for individual operations. Although DynamoDB can scale on demand, it does not do that as quickly as S3. If there are sudden bursts of traffic, requests to DynamoDB may end up throttled for a while.
 
S3 operations generally work on entire items. Atomic batch operations on groups of objects are not possible, and it's difficult to work with parts of an individual object. There are some exceptions to this, such as retrieving byte ranges from an object, but appending content to a single item from multiple sources concurrently is not easy. 

DynamoDB works with structured documents, so its smallest atom of operation is a property inside an item. You can, of course, store binary unstructured information to DynamoDB, but that's not really the key use case. For structured documents, multiple writers can concurrently modify properties of the same item, or even append to the same array. DynamoDB can efficiently handle batch operations and conditional updates, even atomic transactions on multiple items.

S3 is more useful for extract-transform-load data warehouse scenarios than for ad-hoc or online queries. There are services that allow querying structured data within S3, for example [AWS Athena,](https://aws.amazon.com/athena/) but this is slow compared to DynamoDB and relational databases. DynamoDB understands the content of its items, and you can set up indexes for efficiently querying properties of items. 

Both DynamoDB and S3 are designed for parallel work and shards (blocks of storage assigned to different processors), so they need to make allowances for consistency. S3 provides eventual consistency. With DynamoDB you can optionally enforce strong read consistency. This means that DynamoDB is better if you need to ensure that two different processes always get exactly the same information while a record is being updated. 

S3 can pretend to be a web server and let end user devices access objects directly using HTTPS. Accessing data inside Dynamo requires AWS SDK with IAM authorisation.

S3 supports automatic versioning, so it's trivially easy to track a history of changes or even revert an object to a previous state. Dynamo does not provide object versioning out of the box. You can implement it manually, but it's difficult to block the modification of old versions.

Although the pricing models are different enough that there is no straight comparison, with all other things equal DynamoDB ends up being significantly cheaper for working with small items. On the other hand, S3 has several ways of cheaply archiving infrequently used objects. DynamoDB does not have multiple storage classes.

## Quick rule of thumb

As a general rule of thumb, if you want to store potentially huge objects and only need to process individual objects at a time, choose S3. If you need to store small bits of structured data, with minimal latency, and potentially need to process groups of objects in atomic transactions, choose DynamoDB. 

Both systems have workarounds for operations that are not as efficient as they would be in the other system. You can chunk large objects into DynamoDB items, and you can likewise set up a text search engine for large documents stored on S3. But some operations are significantly less hassle with one system than with another. 

The nice aspect of both DynamoDB and S3 is that you do not have to predict capacity or pay for installation fees. There is no upfront investment that you then need to justify by putting all your data into the same place, so you can mix both systems and use them for different types of information. Look at the different usage patterns for different blocks of data then choose between Dynamo or S3 for each individual data type. 

![Typical usage patterns for S3 and DynamoDB](/img/s3ordynamo.png)

At [MindMup](https://www.mindmup.com), for example, we use S3 to store user files and most user requests, such as share invitations and conversion requests. We never need to run ad-hoc queries on those objects or process them in groups. We always access them by primary key, one at a time. We use DynamoDB to store account information, such as subscription data and payment references, because we often query this data based on attributes and want to sometimes process groups of related accounts together. 

## Still need a relational database? 
 
If you really need to get data coming from users into a relational database or a network file system from Lambda, it's often better to create two functions. One can be user-facing, outside a VPC, so that it can start quickly, write to a document database or a transient external storage (such as a queue), and respond to users quickly. The other function can move the data from the document database to the relational storage. You can put another service between the two functions, such as SQS or Kinesis, to buffer and constrain parallel migration work, so that you don't overload the downstream systems and that the processing does not suffer as much from cold starts.

