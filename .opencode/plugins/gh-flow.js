/**
 * gh-flow plugin for OpenCode.ai
 *
 * Auto-registers the skills directory via the config hook (no symlinks needed).
 *
 * This plugin injects no per-session bootstrap context. All four skills are
 * explicitly invoked — you reach for one when you want an issue carried to a
 * PR without hand-driving each atom — so OpenCode's native `skill` tool
 * discovering them is all that is needed. Every one of them writes to GitHub
 * (commits, pushes, PRs, gists), so a preamble nudging the model toward them
 * unprompted would be actively harmful.
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const GhFlowPlugin = async () => {
  const ghFlowSkillsDir = path.resolve(__dirname, '../../skills');

  return {
    // Inject skills path into live config so OpenCode discovers gh-flow
    // skills without requiring manual symlinks or config file edits.
    // This works because Config.get() returns a cached singleton — modifications
    // here are visible when skills are lazily discovered later.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(ghFlowSkillsDir)) {
        config.skills.paths.push(ghFlowSkillsDir);
      }
    },
  };
};
