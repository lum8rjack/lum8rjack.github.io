---
title: "Okta Phishing Detection"
date: 2024-02-07
categories: [ "phishing" ]
tags: ["okta", "browser extension", "prevention"]
draft: false
---

Phishing is still one of the common methods threat actors utilize to breach companies. Most phishing attacks try tricking the victim into revealing sensitive information or downloading and executing malicious attachments and files.

During many of the phishing engagements I have performed, I tend to target organization’s identity and access management services. Okta is one common service that is widely used across the industry and, if compromised, can provide access to many other services in the organization. While Okta and other
services tend to have multifactor authentication (MFA) enabled, users can still be compromised despite this protection.

How does this phishing technique work and what controls can help prevent this? I’m going to walk through one method that uses a custom browser extension to help improve user awareness, specifically related to Okta.

## Phishing For Sessions

Historically, threat actors would replicate the target website and subsequently send the victim a phishing email. The intention is to persuade them to log in to the fraudulent website. Although this method remains effective, it only enables the attacker to obtain the victim's login credentials, preventing the attack from gaining access if MFA is enabled.

There are tools designed to not only capture credentials during phishing but also bypass MFA by acting as a proxy between the victim and the legitimate website. [Evilginx2](https://github.com/kgretzky/evilginx2), one of the tools used describes itself as a “standalone man-in-the-middle attack framework used for phishing login credentials along with session cookies, allowing for the bypass of 2-factor authentication.” I won’t walk through installing and configuring evilginx2, as there are already other blogs that provide those details, but I will provide a simple example.

Imagine a user receives a convincing e-mail stating they have access to a new application through their Okta account. The e-mail contains a link that would direct the victim to the phishing website that is a proxy to the legitimate Okta login page. After the user logs in, the attacker would have successfully captured the victim’s credentials and sessions cookies. The session cookies could then be imported into the attacker’s browser and provide them access the victim’s Okta applications.

![diagram](/img/OktaPhishingDetection/phishing.png)

## Okta Phishing Detection

A browser extension is a software program that adds additional features and functionality to your web browser. These extensions can be used for a wide variety of purposes, including adding additional features, managing cookies, blocking adds, and customizing web pages. Browser extensions can greatly enhance your web browsing experience by adding features and functionality that aren't available in your browser by default.

A few common recommendations against proxy related phishing attacks are to provide security and awareness training to all employees, and consider implementing Universal Second Factor (U2F) MFA to help defend against One-Time Password (OTP) interception attacks. While both can be effective preventative measures, I wanted to research additional ways that could reduce the likelihood of users falling victim to this type of phishing.

I thought of how some clients configure a warning banner on the top of all e-mails that arrive outside of their organization. While it is a simple notification banner for the user, I have found that campaigns are much less effective against clients that have the notification configured.

Some employees receive e-mails every day from 3rd party services and the warning notification would not be as effective against a well-crafted phishing e-mail intended to look like it was sent from a 3rd party service. This made me think, is there a way I could provide another warning to the user once they have clicked a malicious link but have not yet entered their credentials or sensitive information? Thus, the idea for a browser extension that could inform the user that they are currently viewing is a potentially malicious website that is not the legitimate site they thought they were visiting was created.

I ended up creating a Google Chrome extension that displays a banner on Okta login pages to help the user determine if it's a valid login page. Once the extension is loaded, it will display a banner on pages it identifies as Okta login pages. It does this in two ways:

1. Identifies valid login pages based on if the domain is a subdomain of “okta.com”, and has a copyright footer containing “Powered by Okta”
2. Invalid or fake login pages are identified by domains that are not subdomains of “okta.com”, but still having the same copyright footer.

Installing the browser extension is as simple as downloading it from the Google Web Store. The code is also hosted on GitHub if anyone would like to review or customize it for their specific needs.

## Using the Browser Extension

Once the extension is installed and enabled, it automatically starts analyzing each website you visit. The banner text can be changed by clicking on the browser icon.

![extension](/img/OktaPhishingDetection/extension.png)

The settings allow users to change the title and add a custom icon for the valid banner. The custom icon is in case an attacker can adjust their proxy webpage to mimic the extension, it would still need to guess the end user’s icon that was set. When visiting a legitimate Okta login page, a blue banner is added to the top of the page, verifying it’s valid.

![valid](/img/OktaPhishingDetection/valid.png)

Visiting a fake Okta login page will add a red banner to the top of the page, informing the user that the website is not actually an Okta login page.

![fake](/img/OktaPhishingDetection/fake.png)

While the browser extension is a simple concept, it can be a great tool to improve user awareness and reduce the likelihood of users successfully being socially engineered. If you would like to test or use the browser extension, it can be installed from the [Chrome Web Store](https://chromewebstore.google.com/detail/okta-phishing-detection/nfgacdcbhlnhengjkgmaicngehehndga), or from [GitHub](https://github.com/lum8rjack/Okta-Phishing-Detection).

## Additional Phishing Protections

Developers could add additional protections to their websites without requiring users to install a separate browser extension. The two references below provide a great explanation of additional protections.

- [@mrgretzky](https://twitter.com/mrgretzky) explains how web developers can help protect against phishing by implementing client side JavaScript detections.
    - [How Much Is The Phish? Evolving Defences Against Evilginx Reverse Proxy Phishing by Kuba Gretzky](https://www.youtube.com/watch?v=C-Fh4sIdY8c&list=WL&index=51)
- Using honeytokens to detect adversary in the middle (AiTM) phishing attacks.
    - [Using honeytokens to detect (AiTM) phishing attacks on your Microsoft 365 tenant](https://zolder.io/using-honeytokens-to-detect-aitm-phishing-attacks-on-your-microsoft-365-tenant/)


## References

- https://chrome.google.com/webstore/detail/okta-phishing-detection/nfgacdcbhlnhengjkgmaicngehehndga
- https://github.com/lum8rjack/Okta-Phishing-Detection
- https://github.com/kgretzky/evilginx2
