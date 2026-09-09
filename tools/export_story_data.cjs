const fs = require("fs");
const path = require("path");

globalThis.IMS_STORY_MAPS = {
  TYPES: {
    TUTORIAL: "prologue_tutorial",
    WILDERNESS: "wilderness",
    CHAPTER1_FOREST: "forest",
    CHAPTER1_CAVE: "cave",
  },
};
require(path.resolve(process.argv[2]));
fs.mkdirSync(path.dirname(process.argv[3]), { recursive: true });
const graph = globalThis.IMS_STORY_DATA.PROLOGUE;
fs.writeFileSync(process.argv[3], JSON.stringify(graph, null, 2) + "\n");

if (process.argv[4] && process.argv[5]) {
  require(path.resolve(process.argv[4]));
  const actions = new Set(), conditions = new Set();
  for (const node of Object.values(graph.nodes)) {
    if (node.enter?.action) actions.add(node.enter.action);
    if (node.wait?.condition) conditions.add(node.wait.condition);
    for (const choice of node.dialogue?.choices || []) {
      if (choice.action) actions.add(choice.action);
      if (choice.when) conditions.add(choice.when);
    }
  }
  const manifest = {
    source: "IM-SNAKE/prototype",
    nodes: Object.keys(graph.nodes).sort(),
    actions: [...actions].sort(),
    conditions: [...conditions].sort(),
    flags: Object.keys(globalThis.IMS_STORY_STATE.defaultState().flags).sort(),
  };
  fs.writeFileSync(process.argv[5], JSON.stringify(manifest, null, 2) + "\n");
}
