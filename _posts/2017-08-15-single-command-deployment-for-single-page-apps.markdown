---
layout: post
title:  "Single command deployment for single page apps"
date:   2017-08-25 12:00:00 +0200
categories: aws s3 cloudfront
---
Developing a single page app is hard. From the very beginning, you’ll need to make many decisions — decisions like picking a framework, setting the folder structure, configuring linter, and many others.

Some of those tasks are easier because of the ecosystem of the tools surrounding your favorite framework and web development in general. For example, tools like [Create React App](https://github.com/facebookincubator/create-react-app), [Angular CLI](https://cli.angular.io/) and [Create Choo App](https://github.com/choojs/create-choo-app) will help you to setup your favorite framework in a few seconds.

![](img.png)

Often, you don’t have enough time to even think about the deployment when you start your new project. And at some point, you need your app to be publicly accessible because you want to show it to your client, friends, or to add it to your portfolio while you are looking for your first job.

But how can you pick the best place to deploy the app fast? There are many tools for deployment, too. If you go with some new shiny thing, will it scale for production, or will you be forced to make another decision about changing it soon? You can go with Github pages, but what about the HTTPS you need for service workers?

Amazon offers something that can scale, a combination of [Simple Storage Service](https://aws.amazon.com/s3/) (S3) for static website hosting and [CloudFront](https://aws.amazon.com/cloudfront/) as a CDN is a cheap but scalable way to deliver your single page app. Although it takes some time to prepare both of those too, even more if you are not familiar with Amazon Web Services.

There is an easier way, though — introducing [Scotty.js](https://github.com/stojanovic/scottyjs), a simple CLI tool that helps you deploy your website or single page app to Amazon S3 and CloudFront with a single command.

## Beam me up, Scotty

The main idea behind Scotty is to deploy your static website or single page app to Amazon ecosystem with a single command.

It will deploy your static website, set up CDN with HTTPS, and even copy the website URL to your clipboard in a minute or so, depending on your internet speed and the website/app size.

For single page applications, it will also configure redirections, so pushState can work out of the box.

![]()

Let’s see it in action with a simple React application.

## Create React App

Before the deployment, we need the app, so let’s create a simple one using Create React App.

First, create a sample app by running `create react app` command from your terminal:

```shell
create-react-app scotty-cra-example
```

If you do not have the create-react-app command installed, you can get it from NPM here: https://www.npmjs.com/package/create-react-app.

Or if you are using NPM v5, you can run Create React App command without installing it globally with the new `npx` command:

```shell
npx create-react-app -- scotty-cra-example
```

Learn more about npx here: https://medium.com/@maybekatz/introducing-npx-an-npm-package-runner-55f7d4bd282b.

Let’s add React Router to demonstrate how pushState support works. To do so, enter your new project and install React Router as a dependency:

```shell
cd scotty-cra-example

npm install react-router-dom --save
```

Now that everything is installed, let’s add React Router to the project — open “src/App.js” file in your favorite editor and update it to look like a basic example of React Router (https://reacttraining.com/react-router/web/example/basic):

```javascript
import React from 'react'
import {
  BrowserRouter as Router,
  Route,
  Link
} from 'react-router-dom'
import logo from './logo.svg'
import './App.css'

const BasicExample = () => (
  <div className="App">
    <div className="App-header">
      <img src={logo} className="App-logo" alt="logo" />
      <h2>Welcome to React</h2>
    </div>
    <p className="App-intro">
      <Router>
        <div>
          <ul>
            <li><Link to="/">Home</Link></li>
            <li><Link to="/about">About</Link></li>
            <li><Link to="/topics">Topics</Link></li>
          </ul>

          <hr/>

          <Route exact path="/" component={Home}/>
          <Route path="/about" component={About}/>
          <Route path="/topics" component={Topics}/>
        </div>
      </Router>
    </p>
  </div>
)

const Home = () => (
  <div>
    <h2>Home</h2>
  </div>
)

const About = () => (
  <div>
    <h2>About</h2>
  </div>
)

const Topics = ({ match }) => (
  <div>
    <h2>Topics</h2>
    <ul>
      <li>
        <Link to={`${match.url}/rendering`}>
          Rendering with React
        </Link>
      </li>
      <li>
        <Link to={`${match.url}/components`}>
          Components
        </Link>
      </li>
      <li>
        <Link to={`${match.url}/props-v-state`}>
          Props v. State
        </Link>
      </li>
    </ul>

    <Route path={`${match.url}/:topicId`} component={Topic}/>
    <Route exact path={match.url} render={() => (
      <h3>Please select a topic.</h3>
    )}/>
  </div>
)

const Topic = ({ match }) => (
  <div>
    <h3>{match.params.topicId}</h3>
  </div>
)

export default BasicExample
```

Now, if you start your app using `npm start` it should work and look similar to the one from this screenshot:

![Basic React app with React Router on localhost]()

It’s time to build your app using `npm run build` node script. This will create a folder called “build” in root of your project.

## Deploy the app

First install Scotty.js from NPM as a global package by running:

```shell
npm install scottyjs -g
```

Prerequisites for Scotty are:

- Node.js (v4+) with NPM
- AWS account
- AWS credentials — setup tutorial: http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html

Then just run following command:

```shell
scotty --spa --source ./build
```

This command tells Scotty that your app is single page app (SPA) and that the source of your project is in “build” folder.

> Bucket names are global for all users, which means that you need to come up with a unique name for your app — reusing “scotty-cra-example” will not work.

Running this command from your terminal will deploy the app and give you 2 URLs as shown here:

![]()

First one, which is also added to your clipboard, is an HTTP link to AWS S3. The second one is a CloudFront URL that also supports HTTPS.

### CDN and HTTPS

Scotty will set up your project on CloudFront CDN, which means it will be cached and distributed to different regions to decrease latency.
It will also set up HTTPS for free, so your app will be ready to use with service workers or anything else that requires a secure connection.

> Live app: https://d1reyqfbyftmjg.cloudfront.net

## How does it work

![]()

There’s no magic behind Scotty. It uses AWS SDK for Node.js behind the scene.

First, it checks if you already have a default region. Unfortunately, AWS doesn’t give us a default region via AWS SDK. Scotty has a small LevelDB database to store that info. If the region doesn’t exist and is not provided, Scotty will ask you to select it.

Next step is to create a bucket if bucket name is not provided, Scotty will use the name of your current folder. Keep in mind that bucket names are global for all users, hence, you need to come up with a unique name for your bucket.

After bucket is created, Scotty will upload your project to AWS S3 using AWS SDK. If a source flag is not provided, the current folder will be used as a source.
As the last step, if your project is a website or a single page app, Scotty will set up CloudFront CDN with HTTPS support. The difference between SPA and website is that Scotty redirects all of the non-existing pages back to index.html, which allows pushState to work out-of-the-box.

***

What are the next steps?

Try Scotty and let me know if something can be improved. Happy to receive pull requests as new features and improvements are welcome.

> Github repository: https://github.com/stojanovic/scottyjs

The current idea for Scotty is to stay a small library for AWS only, but that doesn’t mean that it can’t be changed.

However, there are a few missing things, such as setting up custom domain names and config file for easier collaboration.

Hope you’ll enjoy it 👽
