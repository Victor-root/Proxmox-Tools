# Contributing

Ideas, fixes and new scripts are welcome. 🎉

This repository patches and configures Proxmox VE hosts as root, so the bar is on **safe, tested and easy to undo**, more than on how much code there is. If you are unsure whether an idea fits, open an issue first and we talk about it before you spend time on it.

## 🔧 Pull requests

Please keep each pull request focused on a single, clear change: one new script, one bug fix, one cleanup.

Good pull requests:

* 🎯 fix or add one clear thing, and avoid unrelated refactors
* 🔒 keep the safety properties: backup before writing, a way back, refusal when the file is not what the script expects
* 🌍 have every text in English and French, in the script and on the website
* 📚 update the README section and the website card together with the script
* 🧪 explain what was tested, and how

Opening several small pull requests is very welcome if that is what it takes to keep each one focused: three unrelated fixes are much easier (and faster) to review as three pull requests than as one big one.

* ✅ good: a new script, with its README section and website card
* ✅ good: a fix to the anchor of one existing patch
* ✅ good: a translation fix
* ⚠️ not ideal: a new script, plus a change to another script, plus a redesign of the site, all in one pull request

The conventions (script layout, translations, backups, README and site format, what to verify) are written down in [AGENTS.md](AGENTS.md). It is written for an AI assistant, but it is just as useful to read yourself.

## 🤖 Contributing with AI assistance

Using AI tools (Claude, ChatGPT, Copilot, etc.) to contribute is totally welcome: it is not a problem, it is not frowned upon, it is actually encouraged.

That does not mean "one prompt, one pull request" though. No vibe coding, where you fire off a prompt and open a pull request with whatever comes out without understanding or checking it. Stay in the driver's seat: understand the problem, guide the AI, review and iterate on what it produces. It is not perfect, and a script that looks right may not be, so everything has to be tested in detail before you submit it: "it runs" is not a test.

* 📖 Ask your assistant to read [AGENTS.md](AGENTS.md) first, so it follows the method of the project instead of inventing its own.
* 🔍 Make it research the real Proxmox sources instead of guessing how Proxmox works, and check what it found.
* 🎯 Ask for a surgical, targeted change: no unsolicited refactors or cleanup. A small, clean diff is easier to get with a good prompt, and easier to review.
* 🧠 You should be able to explain every line you submit.

No issue letting the AI write the pull request title and description, as long as it stays readable by a human: what problem it solves and what the change does, without code level detail (that is for me to see in review). Please mention that the pull request was AI assisted, for transparency, and if you can, briefly describe your workflow (tool used, how you verified it). It is optional, but it helps me calibrate the review.

## 🧪 Testing

Testing is by far the most important part of a pull request, even more so with AI. A patch that looks fine after five minutes can still misbehave later: after a package update, on another version of Proxmox VE, in another browser, on a cluster.

Before opening the pull request, try the script on a real Proxmox VE host (a non critical node first), and test the way back as much as the way forward. In the description, include a short **Testing** section:

* 🖥️ Proxmox VE version, and the version of the package the script patches
* ✅ what you ran: apply, apply again, restore, and what happens when the file is not the expected one
* 🌐 for a change visible in the web interface: the browser(s) used
* ⏱️ how long and in which conditions you used it for real

If you could not test something, say so plainly, it is much better than a silent gap.

## 🌿 Practical details

* Work on a branch named after what you do, in kebab case (for example `xterm-scrollback`), never on `main`.
* Commit messages: English, imperative, a short first line, a body that explains why.
* You do not need to sign your commits, I re-sign when merging.
* Contributions are published under the [GNU AGPL v3](LICENSE), like the rest of the repository.

Thank you for helping make Proxmox a bit less annoying. 🙌
