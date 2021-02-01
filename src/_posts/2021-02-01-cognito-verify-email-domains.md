---
layout: post
title:  "Verify email domains with Cognito"
excerpt: "Prevent bad signups with email domain validation and Cognito PreSignUp triggers"
date: 2020-02-01 11:00:00 +0200
categories: 
  - Serverless
  - CloudFormation
author_name : Gojko Adzic
author_url : /author/gojko
author_avatar: gojko.jpg
twitter_username: gojkoadzic
show_avatar: true
feature_image: cognito-domains-seo.png 
show_related_posts: false
square_related: recommend-gojko
---

Mistyped emails can be a huge problem for user registrations. In this quick tip, I'll show you how to prevent a huge percentage of such problems by adding a Cognito PreSignUp trigger to validate email domains.

At [Narakeet](https://www.narakeet.com), an app I launched recently to help people make narrated videos quickly, about 10% of user registrations go into a black hole because people mistype their email. I've probably seen every possible way to mistype 'gmail' in the email bounce logs. 

Because they can't confirm the registration, users cannot sign in. That makes a very bad first impression. Visitors might think that the application is broken and never come back, instead of fixing their email during registration. To add insult to injury, with an invalid email, I may not be able to get in touch with them to provide assistance. 

## PreSignUp trigger to the rescue

Cognito user pools can be customised with various triggers. The `PreSignUp` trigger allows you to modify the sign-up process. Most of the examples online are showing how to speed up the user funnel, automatically confirming attributes and skipping steps of the usual registration flow. However, we can also use this trigger to slow users down then they make a mistake.

Here's a trivial Node.js Lambda function that will check if the domain of the user provided email exists, and if it's configured to receive incoming email. It also logs some basic information for CloudWatch insights.

```js
'use strict';
const dns = require('dns');
exports.handler = async (event) => {
	const email = event.request.userAttributes.email,
		domain = email.replace(/^.*@/, '') || '';
	try {
		if (!domain) {
			throw 'Email format invalid';
		}
		const servers = await dns.promises.resolveMx(domain);
		if (Array.isArray(servers) && servers.length > 0) {
			console.log(JSON.stringify({verification: true, domain}));
			return event;
		} else {
			throw 'no-servers';
		}
	} catch (error) {
		console.log(JSON.stringify({verification: false, domain, error}));
		throw `Cannot verify email domain ${domain}. Please check for typos`;
	}
};
```

When a user mistypes `gmail.com` as `gmal.com`, instead of proceeding with the signup, they will see a message such as the one below:

![](/img/cognito-domains-big.png)

The error isn't ideal - I would prefer not to have the initial part showing users that a trigger failed, but with Cognito hosted UI that's the best you can get.

Of course, this doesn't protect you from people mistyping the first part of their email, or mistyping a domain that can also receive messages, but it will at least prevent a large portion of email issues. Popular email providers tend to buy up similarly-sounding domains to prevent squatting, so in practice this little trick can save a lot of users from dropping off the funnel.

