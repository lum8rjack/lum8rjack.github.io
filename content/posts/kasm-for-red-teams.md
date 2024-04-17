---
title: "Kasm for Red Teams"
date: 2024-04-07T12:00:28-05:00
categories: [ "infrastructure" ]
tags: ["kasm", "phishing"]
draft: false
---

Have you ever successfully phished a target during a red team engagement and received access to one of their online accounts? There are times you need to keep your browser session active after bypassing MFA so you aren't logged out. You might have to leave your computer on for multiple days or if you are using a VPN, hope that it doesn't disconnect. If multiple team members are on the project, it also makes it difficult to distribute the work if everyone is working remote and on their own machines.

In this post, I’m going to walk through one method I found that allows you to share a browser with other team members and host it on your current infrastructure.

## Current Infrastructure Setup

The diagram below shows an example of what the instructure may look like during a phishing campaign. The target is tricked into authenticating to their website through our MitM server. Tester 1 then uses the compromised credentials/cookies to authenticate to the real website. The downside to this setup is that a compromised target's browser session is only accessible from one of the tester's machines.

![current phishing diagram](/img/Kasm/current-phishing-diagram.png)

 A second option available is each tester could use the captured credentials or session cookies to access the website on their own machines. However this method also has downsides including:
- If a new login was made from an unknown IP the target may receive an e-mail alert
    - This could be solved by having all testers proxy their traffic through the same location (VPS)
- The web application may show all active sessions which could be alarming if the target or IR sees all of the sessions
- If the target's credentials are changed during the campaign you may not be able to create new sessions
- If you were only able to initially access the website because the target accepted a MFA push notification and you don't want to risk sending another push notification

To solve these issues, you would need to use one browser throughout the entire campaign. The browser would also need to be active from the same IP the entire time and shared between all team members.


## Kasm Workspaces - Shared Browser

One of the solutions I found was to use [Kasm Workspaces](https://kasmweb.com/) to share a browser between team members. Kasm provide a list of containerized applications and desktops that can easily be deployed with Docker. You can use their stand-alone Firefox workspace to setup a shared browser for multiple team members to utilize during testing. Once deployed, the infrastructure will look similar to the diagram below.

![updated phishing diagram](/img/Kasm/updated-phishing-diagram.png)

With this setup, the browser traffic is coming from the same IP as the phishing setup and accessible from every team member.

You can install the Kasm Firefox workspace using the following commands:

```bash
git clone https://github.com/kasmtech/workspaces-images
cd workspaces-images
docker build -t kasmweb/firefox:dev -f dockerfile-kasm-firefox .
docker run --rm --name firefox --shm-size=512m -p 6901:6901 -e VNC_PW=password -d kasmweb/firefox:dev
```

Once the docker image is built and the container is running in the background, you can access the container via a browser at `https://<IP>:6901` and use the credentials `kasm_user:password`.

![kasm firefox](/img/Kasm/kasm-firefox.png)

Any members of the team can connect to the container at the same time to work in the browser or just view what is happening.

![multiple connections](/img/Kasm/multiple-connections.png)

The Kasm VNC settings also alow you to change the session to view only if a team member only wants to follow along without controlling the browser.

![read only](/img/Kasm/read-only.png)

During the setup, you can also install any browser extensions that you would normally need (ex.[Container proxy](https://addons.mozilla.org/en-US/firefox/addon/container-proxy/?utm_source=addons.mozilla.org&utm_medium=referral&utm_content=search), [Cookie-Editor](https://addons.mozilla.org/en-US/firefox/addon/cookie-editor/), [Tab Reloader](https://addons.mozilla.org/en-US/firefox/addon/tab-reloader/)). Once you are done for the day, you can close your main browser and the Kasm Firefox session will stay active and ready to continue for the next person or the next day.


## References

- [Kasm](https://kasmweb.com/)
- [Kasm Workspace Images](https://github.com/kasmtech/workspaces-images)
