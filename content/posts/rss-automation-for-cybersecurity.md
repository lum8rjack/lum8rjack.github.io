---
title: "RSS Automation for Cybersecurity"
date: 2024-12-23T07:20:28-06:00
categories: [ "news" ]
tags: ["rss", "n8n", "automation"]
draft: false
---

Staying ahead in the fast-paced world of cybersecurity is not always easy. With new vulnerabilities, threats, and tools emerging almost daily, keeping up with the latest information can feel overwhelming. In this blog post, I’ll share how I navigate the flood of cybersecurity news and updates, leveraging a mix of platforms and automation to ensure I’m always in the loop.

## My Main Sources for Cybersecurity News

For me, staying current begins with actively following the right sources. Platforms like X and Reddit are invaluable for real-time updates and discussions, while YouTube channels provide in-depth analyses and tutorials. The cornerstone of my approach lies in automating the process of staying updated on the latest blog posts and articles from trusted sources using RSS feeds. This automation ensures that I don’t miss critical updates while saving me time to focus on what matters most.

I’ll delve into the specific tools and strategies I use to monitor RSS feeds and the automation to notify me on a daily basis.

## n8n: Workflow Automation Made Easy

One of the first tools I configured for staying updated was [n8n](https://n8n.io/), an open-source workflow automation tool. n8n allows users to design powerful automation workflows without requiring extensive programming knowledge. It connects various services and applications, enabling you to automate repetitive tasks seamlessly. What makes n8n particularly appealing is it's flexibility and self-hosting capability, ensuring full control over your data.

In my setup, n8n runs as a Docker container and aggregates updates on a daily basis. Below is an example of my Docker Compose file:

```yml
services:
  n8n:
    image: n8nio/n8n
    container_name: n8n
    hostname: n8n
    environment:
      - "TZ=America/Chicago"
      - "N8N_SECURE_COOKIE=false"
    volumes:
      - ./n8n:/home/node/.n8n
    ports:
      - 5678:5678
    restart: unless-stopped
```

Once it's up and running, you can create a new workflow and add different triggers that feed into each other. You can follow n8n's documentation to set up your own service, but below is an example of how my workflow initially looked:

![n8n RSS Automation](/img/RSS/n8n-rss-automation.png)

It performed the following tasks:

- **Schedule Trigger**: Start the workflow every morning at 7:30 AM.
- **Date & Time**: Determines yesterday's date so I only get new articles posted in the last 24 hours.
- **RSS Read**: A RSS trigger for each RSS feed I want to monitor.
- **If**: Loops through each article in the feed and checks if it was published yesterday.
- **Code**: Collects all the new posts and builds out the message.
- **Discord**: Posts the message to Discord for me to view.

This setup has significantly streamlined how I consume cybersecurity news, allowing me to focus on analysis and action rather than sifting through endless streams of information.

A few downsides to this setup include:
- **Adding New RSS Feeds**: Adding a new trigger for each feed can feel excesive. I'm sure there's a way to consolidate this process to use one trigger for multiple feeds.
- **Empty Messages**: Some days, there are no new posts, yet I still receive an empty Discord message. Adding conditional triggers could resolve this.
- **Overkill**: While n8n has been useful, I don't use it for other automations, making it feel like overkill for this single use case.


## Custom RSS Reader

While n8n has been a great tool for automating my workflow, I eventually wanted a more lightweight and tailored solution. This led me to create a simple CLI tool that performs the same steps as my n8n setup but with fewer resources and greater customization. By building this tool, I was able to streamline the process even further and address some of the limitations of my n8n workflow. 

To use my custom RSS reader, download and build the tool from [Github](https://github.com/lum8rjack/rss-monitor). Then start by creating a text file containing the RSS feeds you want to monitor. Below is an example of the feeds I track:

```txt
# List of RSS websites
https://blog.lum8rjack.com/index.xml
https://blog.badsectorlabs.com/feeds/all.atom.xml
https://blog.huntr.com/rss.xml
https://blog.portswigger.net/feeds/posts/default
https://isc.sans.edu/rssfeed.xml
https://labs.jumpsec.com/feed/
https://labs.nettitude.com/feed/
https://labs.watchtowr.com/rss/
https://research.openanalysis.net/feed.xml
https://sensepost.com/rss.xml
https://www.blackhillsinfosec.com/feed/
https://www.mandiant.com/resources/blog/rss.xml
https://www.netspi.com/blog/technical/feed/
https://www.pentestpartners.com/security-blog/feed
https://www.trustedsec.com/feed.rss
https://www.zerodayinitiative.com/blog/?format=rss
https://www.zerodayinitiative.com/rss/published/
```

Next, create a message template for the output. The tool replaces the `.Date` field with the current date and loops through each post to generate a list of titles and links:

```txt
*:new: Posts from {{ .Date }} :new:*

{{ range .Posts }}
{{ .Title }} | {{ .Link }}
{{- end }}
```

Finally, set up a Discord or Slack bot and run the tool using a command like this:

```bash
./rss-monitor discord -d -t templates/discord-message.txt -r templates/rss-links.txt -w  https://discord.com/api/webhooks/xxxxxxxx/yyyyyyyyyyyyyyyy
```

I've schedule this tool to run daily at 7:30 AM using a cron job, ensuring I receive all relevant updates.

![Discord Message](/img/RSS/rss-monitor-message.png)

## Conclusion

Whether you’re using a full-fledged automation tool like n8n or a lightweight custom CLI solution, staying informed in the cybersecurity world doesn’t have to be a daunting task. By leveraging automation and tailoring your setup to fit your needs, you can focus more on understanding and responding to new threats rather than searching for updates. I hope this blog has given you some ideas to improve your own workflow.


## References

- [n8n](https://n8n.io/)
- [rss-monitor](https://github.com/lum8rjack/rss-monitor)
