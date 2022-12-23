# lum8rjack.github.io

Personal website created using [Hugo](https://gohugo.io/) and the [hyde-hyde](https://themes.gohugo.io/themes/hyde-hyde/) theme.

## Hugo

Basic commands to remember when building

```bash
# Make a new post
hugo new content/posts/<blog name>.md

# Run hugo server
hugo server -D

# Run hugo on specific IP
hugo server -D --bind 10.10.10.5

# Build site (config.toml has the default build location)
hugo -D

# Build site and save to specific directory
hugo -D -c docs/
```
