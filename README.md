# A digital resume by and for Adam Kauffman

Live site: [adamkauffman.dev](https://adamkauffman.dev)

When it came time to make a new resume website, I decided to try out a static site generator. I chose Jekyll so I could pair structured YAML content with an automated CI/CD build and deployment pipeline and free static hosting.

I procured a `.dev` domain not only to signify that I am a developer, but because this top-level domain (TLD) enforces HTTPS via HSTS preload and is built for developers. That's what this resume site is: a technical sandbox and portfolio at the same time.

Front-end design is not my primary specialty, so I started from the [Orbit](https://themes.3rdwavemedia.com) Jekyll resume template and stripped it down to just what this site uses. That let me focus on the build pipeline, accessibility, and content architecture without getting bogged down in a full visual redesign.

This was my first foray into both Jekyll and the Ruby ecosystem. I really like build-time static site generation—pre-compiling templates and assets ahead of time keeps the runtime payload tiny and fast for visitors. Overall, the experience was quite positive, and I picked up a few useful things along the way.

## Local development

Ruby version is pinned in [`.ruby-version`](.ruby-version).

```bash
bundle install
bundle exec jekyll serve
```

## History in picture

```mermaid
---
title: My language learning path
---
graph TD;
    QBasic --> TurboPascal
    TurboPascal --> C
    C --> VBA
    VBA --> VB.NET
    VBA --> Python
    VBA --> Access
    Access --> SQL
    VB.NET --> C#
    VB.NET --> G-Code
    C --> HTML
    HTML --> CSS
    HTML --> PHP
    HTML --> JavaScript
    HTML --> Razor
    CSS --> Razor
    C# --> Razor
    Razor --> Blazor
    JavaScript --> Razor
    JavaScript --> TypeScript
    HTML --> Jekyll
    Jekyll --> Ruby
    Ruby --> Ruby on Rails
```
