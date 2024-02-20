---
title: "C2 Redirectors Made Easy"
date: 2024-02-18
categories: [ "infrastructure" ]
tags: ["caddy", "C2", "proxy"]
draft: false
---

In penetration testing and red teaming campaigns, Command-and-Control (C2) servers are used to simulate the control infrastructure that an attacker might use. These servers facilitate communication between the simulated malicious actors and the compromised systems. Using a proxy server, also known as a redirector, in front of a C2 server serves several important purposes:
- Obscure the actual location of the C2 server.
- Allow only legitimate C2 traffic to reach the C2 server.
- If the traffic is detected and blocked, the proxy can easily be destroyed and a new one deployed in it's place. This is easier than re-deploying the C2 server.

While deploying a redirector is relatively easy, one of the slow aspects is configuring the proxy rules to only allow legitimate C2 traffic to the C2 server. This involves reviewing the C2 profile and adding redirect rules to the proxy configuration file based on the User-Agent and each of the http endpoints. Any time the C2 profile updates any of the routes, you would also need to manually update the proxy configuration. 

With this in mind, I decided to develop a Caddy module, called [caddy-c2](https://github.com/lum8rjack/caddy-c2), which easily parses the C2 profile and proxies the C2 traffic without needing to manually add the routes.

## Caddy

If you don't alread know, [Caddy](https://caddyserver.com/) is a modern, open-source web server written in Go. It's designed to be easy to use, efficient, and extensible. A few aspects of Caddy that stand out include:

1. **Automatic HTTPS:** Caddy automatically manages SSL/TLS certificates for your sites using Let's Encrypt, making it incredibly easy to set up secure connections without any manual configuration.
2. **Configuration:** Caddy's configuration is a single-file that is simple and human-readable.
3. **Built-in Middleware:** Caddy comes with a rich set of built-in middleware, enabling features like gzip compression, CORS, rate limiting, and more without the need for third-party modules or plugins.
4. **Extensibility:** While Caddy comes with many features out of the box, it also supports plugins for extending its functionality further. This allows users to add custom features or integrate with other systems as needed.

## Normal Proxy

Whichever proxy you decide to use (Caddy, Apache, Nginx, etc.), you would have to review the C2 profile, identify what to base the proxy rules on, and then update the configuration appropriately. Below contains part of a Cobalt Strike profile that show the User-Agent and URIs that could be used for proxying.

```
set sleeptime "37500";
set jitter    "33";
set useragent "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/587.38 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36";  
set data_jitter "50";
...
http-get {
    set uri "/login /config /admin";
    ...
}
...
http-post {
    set uri "/Login /Config /Admin";
    ...
}
...
http-stager {
    set uri_x86 "/Console";
    set uri_x64 "/console64";
    ...
}
```

Using this profile, you would need to manually add the URIs, User-Agent, and any other checks in your configuration file to redirect traffic appropriately. Below is one example of a Caddyfile that could be used with Caddy to proxy the C2 traffic. The main areas to focus on include: the blocks containing the method, path, and header.

```
{
    admin off
    debug
}

(c2) {
    reverse_proxy https://localhost:8080 {
        tls
        tls_insecure_skip_verify
    }
}

http://127.0.0.1:3333 {
    # Check the GET URIs
    @geturis {
        method GET
        path /login /config /admin /Console /console64
        header User-Agent Mozilla/5.0 (Windows NT 6.1) AppleWebKit/587.38 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36  
    }

    # Check the POST URIs
    @posturis {
        method POST
        path /Login /Config /Admin
        header User-Agent Mozilla/5.0 (Windows NT 6.1) AppleWebKit/587.38 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36  
    }

    # Handle GET
    handle @geturis {
        import c2
    }

    # Handle POST
    handle @posturis {
        import c2
    }

    # Return 503 for all other traffic
    handle /* {
        respond 503
    }
}
```

The configuration file is pretty straight forward, but any time you want to adjust the C2 profile you would also need to update the Caddyfile.


## Caddy-C2

I decided it would be easier to build a Caddy module to automatically route traffic based on the C2 profile without needing to adjust anything in the Caddyfile. Caddy provides great documentation on how to create new modules.
- [Extending Caddy](https://caddyserver.com/docs/extending-caddy)
- [Modules namespaces](https://caddyserver.com/docs/extending-caddy/namespaces)

What I found the most useful was looking at how current [modules](https://caddyserver.com/docs/modules/) were developed and using that information to make my own module. The [caddy-c2](https://github.com/lum8rjack/caddy-c2) I made uses the `http.matchers` namespace and performs the following actions:
- Parses the C2 profile when Caddy starts (thanks to [goMalleable](https://github.com/D00Movenok/goMalleable)) to get the following details
    - User-Agent
    - All the GET URIs
    - All the POST URIs
- Checks all incoming traffic against the parsed data

To install a new module, you must have Go installed to build a new version of Caddy. Caddy has a tool call `xcaddy` that makes it simple to build Caddy with plugins. The first command installs xcaddy, and the second command builds Caddy with the caddy-c2 module.

```bash
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
xcaddy build --with github.com/lum8rjack/caddy-c2
```

Once Caddy is built, you can confirm the module was added by running the following command:

```bash
caddy list-modules
```

The output should include the `http.matchers.c2_profile` non-standard module.

```bash
tls.stek.distributed
tls.stek.standard

  Standard modules: 106

http.matchers.c2_profile

  Non-standard modules: 1

  Unknown modules: 0
```


Using the same Cobalt Strike profile shown above, the Caddyfile can be simplified by including the `c2_profile` module. This module requires you to specify the C2 profile and the C2 framework you will use. The module currently only supports Cobalt Strike for the C2 framework, but will hopefully be updated to include other C2 frameworks in the future.

```
{
    admin off
    debug
}

(c2) {
    reverse_proxy https://localhost:8080 {
        tls
        tls_insecure_skip_verify
    }
}

http://127.0.0.1:3333 {
    # Setup the c2_profile to match on the network traffic
    @profile {
        c2_profile {
            profile "/tmp/cobaltstrike.profile"
            framework "cobaltstrike"
        }
    }

    # Handle anything related to the C2 profile
    handle @profile {
        import c2
    }

    # Return 503 for all other traffic
    handle /* {
        respond 503
    }
}
```

For a basic test, the following Caddyfile was used to manually check that the URI paths and User-Agent work correctly.

```
{
    admin off
    debug
}

http://127.0.0.1:3333 {
    @c2 {
        c2_profile {
            profile "/tmp/cobaltstrike.profile"
            framework "cobaltstrike"
        }
    }

    handle @c2 {
        respond "redirecting to C2"
    }

    handle /* {
        respond "bad request"
    }
}
```

Caddy is started using the provided Caddyfile.

```bash
./caddy run -c Caddyfile
```

The `curl` command was then used to manually send requests and validate what is redirected to the C2. The output from each of the curl requests is shown below, confirming the module is working correctly.

```bash
root@ubuntu:/# curl http://127.0.0.1:3333/testing
bad request
root@ubuntu:/# curl -A "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/587.38 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36" http://127.0.0.1:3333/testing
bad request
root@ubuntu:/# curl -A "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/587.38 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36" http://127.0.0.1:3333/config
redirecting to C2
root@ubuntu:/# curl -A "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/587.38 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36" http://127.0.0.1:3333/admin
redirecting to C2
root@ubuntu:/# curl -A "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/587.38 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36" http://127.0.0.1:3333/admin?file=testing123
redirecting to C2
root@ubuntu:/# curl -A "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/587.38 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36" -X POST -d "key1=value1" http://127.0.0.1:3333/data
bad request
root@ubuntu:/# curl -A "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/587.38 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36" -X POST -d "key1=value1" http://127.0.0.1:3333/Admin
redirecting to C2
```

Since the Caddyfile set logging to `debug` mode, Caddy outputs additional information related to the C2 module and whether the traffic matched the C2 profile.

```bash
2024/02/18 22:44:44.718 DEBUG   http.matchers.c2_profile        failed User-Agent check {"ip": "127.0.0.1:52110", "method": "GET", "uri": "/testing"}
2024/02/18 22:45:22.961 DEBUG   http.matchers.c2_profile        failed GET check        {"ip": "127.0.0.1:51702", "method": "GET", "uri": "/testing"}
2024/02/18 22:45:28.406 DEBUG   http.matchers.c2_profile        passed all checks       {"ip": "127.0.0.1:34426", "method": "GET", "uri": "/config"}
2024/02/18 22:45:35.632 DEBUG   http.matchers.c2_profile        passed all checks       {"ip": "127.0.0.1:51446", "method": "GET", "uri": "/admin"}
2024/02/18 22:45:42.582 DEBUG   http.matchers.c2_profile        passed all checks       {"ip": "127.0.0.1:51460", "method": "GET", "uri": "/admin?file=testing123"}
2024/02/18 22:47:59.545 DEBUG   http.matchers.c2_profile        failed POST check       {"ip": "127.0.0.1:55222", "method": "POST", "uri": "/data"}
2024/02/18 22:48:07.217 DEBUG   http.matchers.c2_profile        passed all checks       {"ip": "127.0.0.1:45598", "method": "POST", "uri": "/Admin"}
```

This module removes the need to update the redirector rules every time the C2 profile is changed. Future improvements would be to include other C2 frameworks like [Mythic](https://github.com/its-a-feature/Mythic) and [Havoc](https://github.com/HavocFramework/Havoc).


## References

- https://github.com/lum8rjack/caddy-c2
- https://github.com/caddyserver/xcaddy
- https://github.com/D00Movenok/goMalleable
