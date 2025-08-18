#!/usr/bin/env bun

import { parseArgs } from "util";
import fs from "fs/promises";
import process from "process";

const chatUrlPrefix = "https://chatgpt.com/c/";

const haveBun = typeof Bun !== "undefined";
async function loadFileJson(path) {
  return haveBun ? Bun.file(path).json() : JSON.parse(await fs.readFile(path));
}
async function fileExists(path) {
  return haveBun
    ? Bun.file(path).exists()
    : fs
        .stat(path)
        .then(() => true)
        .catch(() => false);
}
const writeFile = haveBun ? Bun.write : fs.writeFile;

async function conversations(jsonPath, { id, after }) {
  const list = await loadFileJson(jsonPath);
  if (id) {
    for (const conversation of list) {
      if (conversation.id === id) {
        return [conversation];
      }
    }
    die(`${id}: conversation not found`);
  }
  if (after) {
    const afterTimestampSeconds = new Date(after).getTime() / 1000;
    const result = [];
    for (const conversation of list) {
      if (conversation.update_time > afterTimestampSeconds) {
        result.push(conversation);
      }
    }
    return result;
  }
  return list;
}

function render(conversation, { includeFrontmatter}) {
  const created = parseDate(conversation.create_time);
  const messages = [];
  let node = conversation.current_node;
  const mapping = conversation.mapping;
  while (node !== null) {
    node = mapping[node];
    if (
      node.message?.content?.parts?.length > 0 &&
      node.message.author.role !== "system"
    ) {
      const message = node.message;
      const role = message.author.role;
      const chatgpt = role === "assistant" || role === "tool";
      const content = message.content;
      const type = content.content_type;
      let text = "";
      if (type === "text" || type === "multimodal_text") {
        for (const part of content.parts) {
          let str = "";
          if (typeof part === "string" && part.length > 0) str = part;
          else if (part.content_type === "audio_transcription") str = part.text;
          text += postProcess(str, chatgpt);
        }
      }
      if (text) messages.push(text);
    }
    node = node.parent;
  }
  messages.reverse();
  const frontmatter = includeFrontmatter ? `\
---
created: ${created.toISOString().slice(0, 10)}
---
` : "";
  return frontmatter + `\
${chatUrlPrefix}${conversation.id}

${messages.join("\n").trimEnd()}`;
}

function parseDate(seconds) {
  return new Date(seconds * 1000);
}

function removePrefix(str, prefix) {
  return str.startsWith(prefix) ? str.slice(prefix.length) : str;
}

function getTitle(conversation) {
  let title = conversation.title;
  if (!title) return "Untitled";
  return title
    .replace(/\.$/, "")
    .replace(/(\S): /, "$1 - ")
    .replaceAll(":", "-")
    .replaceAll("/", "\u29f8") // big solidus
    .replaceAll("\\", "\u29f9"); // big reverse solidus
}

function postProcess(msg, chatgpt) {
  if (chatgpt) {
    // Remove citation/metadata markers.
    msg = msg.replace(/\ue200.*?\ue201/g, "");
    // Remove other weird markers.
    msg = msg.replace(/[\ue203\ue204\ue206]/g, "");
  } else {
    // Obsidian syntax
    // https://help.obsidian.md/callouts
    msg = "> [!note] Prompt\n" + msg.replace(/^/gm, "> ");
  }
  return msg ? msg.trim() + "\n" : "";
}

const args = parseArgs({
  args: process.argv,
  options: {
    out: { type: "string" },
    after: { type: "string" },
    "no-frontmatter": { type: "boolean" },
    h: { type: "boolean" },
    help: { type: "boolean" },
  },
  strict: true,
  allowPositionals: true,
});

function usageAndExit(code) {
  console.log(`\
Usage: ${process.argv[1]} JSON_FILE [CHAT_ID] [--out OUT_DIR] [--after DATE]

Convert ChatGPT conversations.json to Markdown files

To get the JSON file, export your data:
https://help.openai.com/en/articles/7260999-how-do-i-export-my-chatgpt-history-and-data

If CHAT_ID is provided, only converts that conversation.
You can also just provide the full URL.

Options:
    --out OUT_DIR     Write Markdown files in this directory
    --after DATE      Only convert conversations updated after this time
    --no-frontmatter  Don't emit frontmatter (with "created" property)
`);
  process.exit(code);
}

function die(msg) {
  console.error(msg);
  process.exit(1);
}

if (args.values.h || args.values.help) usageAndExit(0);
const numArgs = args.positionals.length;
if (numArgs < 3 || numArgs > 4) usageAndExit(1);
const jsonPath = args.positionals[2];
const idOrUrl = args.positionals[3];
const outDir = args.values.out;
const after = args.values.after;
if (!(idOrUrl || outDir)) die("must provide either CHAT_ID or --out");
if (idOrUrl && after) die("CHAT_ID and --after are mutually exclusive");
const id = idOrUrl && removePrefix(idOrUrl, chatUrlPrefix);
const includeFrontmatter = !args.values["no-frontmatter"];

for (const conversation of await conversations(jsonPath, { id, after })) {
  const content = render(conversation, { includeFrontmatter});
  if (outDir) {
    const base = `${outDir}/${getTitle(conversation)}`;
    let path = `${base}.md`;
    let n = 1;
    while (await fileExists(path)) path = `${base} (${++n}).md`;
    const updated = conversation.update_time;
    writeFile(path, content).then(() => fs.utimes(path, updated, updated));
  } else {
    console.log(content);
  }
}
