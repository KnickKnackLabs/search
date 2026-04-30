/** @jsxImportSource jsx-md */

import { readFileSync, readdirSync } from "fs";
import { join, resolve } from "path";

import {
  Heading, Paragraph, CodeBlock,
  Bold, Code, Link,
  Badge, Badges, Center, Section,
  List, Item,
} from "readme/src/components";

const REPO_DIR = resolve(import.meta.dirname);
const testDir = join(REPO_DIR, "test");
const testFiles = readdirSync(testDir).filter((f) => f.endsWith(".bats"));
const testCount = testFiles.reduce((sum, f) => {
  const content = readFileSync(join(testDir, f), "utf-8");
  return sum + (content.match(/@test /g)?.length ?? 0);
}, 0);

const readme = (
  <>
    <Center>
      <Heading level={1}>search</Heading>

      <Paragraph>
        <Bold>Search across the knowledge providers you already have access to.</Bold>
      </Paragraph>

      <Paragraph>
        Home notes, HUMAN.md, web results, GitHub issues, pull requests, and code
        search — one provider-shaped interface instead of another pile of one-off commands.
      </Paragraph>

      <Badges>
        <Badge label="shell" value="bash" color="4EAA25" logo="gnubash" logoColor="white" />
        <Badge label="runtime" value="mise" color="7c3aed" href="https://mise.jdx.dev" />
        <Badge label="tests" value={`${testCount} passing`} color="brightgreen" />
        <Badge label="providers" value="6" color="blue" />
      </Badges>
    </Center>

    <Section title="Shape">
      <Paragraph>
        The command is explicit about which provider is being searched. There is no
        naked <Code>{`search "query"`}</Code> entry point; use <Code>search all</Code>{" "}
        for blended search or choose a provider directly.
      </Paragraph>

      <CodeBlock lang="bash">{`search all "query"
search notes "query"
search human "query"
search web "query"
search issues --repo OWNER/REPO "query"
search prs --repo OWNER/REPO "query"
search code --repo OWNER/REPO "query"
search providers`}</CodeBlock>
    </Section>

    <Section title="Providers">
      <List>
        <Item><Code>notes</Code> — local markdown sources: home notes, plus discovered <Code>home/modules/*</Code> modules</Item>
        <Item><Code>human</Code> — Or's HUMAN.md via <Code>HUMAN_MD</Code> or <Code>SEARCH_SOURCE_HUMAN</Code></Item>
        <Item><Code>web</Code> — Brave Search API</Item>
        <Item><Code>issues</Code> — GitHub issues via <Code>gh search issues</Code></Item>
        <Item><Code>prs</Code> — GitHub pull requests via <Code>gh search prs</Code></Item>
        <Item><Code>code</Code> — GitHub code via <Code>gh search code</Code></Item>
      </List>
    </Section>

    <Section title="Blended search">
      <Paragraph>
        <Code>search all</Code> runs configured providers. Local notes are always
        included. HUMAN.md is included when available. Web is included when{" "}
        <Code>BRAVE_SEARCH_API_KEY</Code> is set. GitHub providers are included
        when they have a default repo configured or a repo override is supplied.
      </Paragraph>

      <CodeBlock lang="bash">{`# Search every configured provider
search all "modules init"

# Provider flags select only those providers
search all --notes --issues "explicit model"
search all --human "obfuscated home"

# Provider-prefixed overrides configure individual providers
search all --notes-limit 3 "frontmatter"
search all --issues --issues-repo KnickKnackLabs/shimmer --issues-limit 5 "model"`}</CodeBlock>

      <Paragraph>
        No <Code>--no-*</Code> flags are provided yet. Selection flags are the
        simpler narrowing mechanism.
      </Paragraph>
    </Section>

    <Section title="Provider defaults">
      <Paragraph>
        Each provider owns its own defaults. Override provider settings with
        environment variables using <Code>SEARCH_&lt;PROVIDER&gt;_&lt;VARIABLE&gt;</Code>.
      </Paragraph>

      <CodeBlock lang="bash">{`SEARCH_NOTES_LIMIT=5 search notes "query"
SEARCH_HUMAN_LIMIT=5 search human "query"
SEARCH_WEB_LIMIT=3 search web "query"
SEARCH_ISSUES_DEFAULT_REPO=KnickKnackLabs/shimmer search issues "model plumbing"
SEARCH_PRS_DEFAULT_REPO=KnickKnackLabs/search search prs "provider"
SEARCH_CODE_DEFAULT_REPO=KnickKnackLabs/search search code "search_all"`}</CodeBlock>

      <Paragraph>
        GitHub providers intentionally do not hardcode organization defaults.
        Pass <Code>--repo OWNER/REPO</Code> or set the provider's default repo env var.
      </Paragraph>
    </Section>

    <Section title="Web search">
      <CodeBlock lang="bash">{`export BRAVE_SEARCH_API_KEY=...
search web --limit 5 "mise tasks"
search web --json "mise tasks"`}</CodeBlock>
    </Section>

    <Section title="Local notes and HUMAN.md">
      <CodeBlock lang="bash">{`search notes "frontmatter"
search notes --source <module-name> "modules init"
search human "obfuscated home"`}</CodeBlock>

      <Paragraph>
        <Code>notes</Code> searches markdown in the agent's home and discovered
        modules under <Code>home/modules/*</Code>. <Code>human</Code> stays a
        separate provider even though <Code>search all</Code> includes it when
        available. Available sources are shown by <Code>search providers</Code>.
      </Paragraph>
    </Section>

    <Section title="Development">
      <CodeBlock lang="bash">{`gh repo clone KnickKnackLabs/search
cd search
mise trust && mise install
mise run test
readme build --check`}</CodeBlock>

      <Paragraph>
        Tests use <Link href="https://github.com/bats-core/bats-core">BATS</Link> — {testCount} tests
        across {testFiles.length} suite{testFiles.length === 1 ? "" : "s"}.
      </Paragraph>
    </Section>

    <Center>
      <Paragraph>
        README generated from <Code>README.tsx</Code> with{" "}
        <Link href="https://github.com/KnickKnackLabs/readme">readme</Link>.
      </Paragraph>
    </Center>
  </>
);

console.log(readme);
