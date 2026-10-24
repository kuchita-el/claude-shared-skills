// 生成物。手で直さない。正本は tools/living-spec/src（pnpm build で作り直す）
import { createRequire } from 'node:module'; const require = createRequire(import.meta.url);
var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
  get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
}) : x)(function(x) {
  if (typeof require !== "undefined") return require.apply(this, arguments);
  throw Error('Dynamic require of "' + x + '" is not supported');
});
var __commonJS = (cb, mod) => function __require2() {
  return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
};
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/identity.js
var require_identity = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/identity.js"(exports) {
    "use strict";
    var ALIAS = Symbol.for("yaml.alias");
    var DOC = Symbol.for("yaml.document");
    var MAP = Symbol.for("yaml.map");
    var PAIR = Symbol.for("yaml.pair");
    var SCALAR = Symbol.for("yaml.scalar");
    var SEQ = Symbol.for("yaml.seq");
    var NODE_TYPE = Symbol.for("yaml.node.type");
    var isAlias = (node) => !!node && typeof node === "object" && node[NODE_TYPE] === ALIAS;
    var isDocument = (node) => !!node && typeof node === "object" && node[NODE_TYPE] === DOC;
    var isMap2 = (node) => !!node && typeof node === "object" && node[NODE_TYPE] === MAP;
    var isPair = (node) => !!node && typeof node === "object" && node[NODE_TYPE] === PAIR;
    var isScalar = (node) => !!node && typeof node === "object" && node[NODE_TYPE] === SCALAR;
    var isSeq = (node) => !!node && typeof node === "object" && node[NODE_TYPE] === SEQ;
    function isCollection(node) {
      if (node && typeof node === "object")
        switch (node[NODE_TYPE]) {
          case MAP:
          case SEQ:
            return true;
        }
      return false;
    }
    function isNode(node) {
      if (node && typeof node === "object")
        switch (node[NODE_TYPE]) {
          case ALIAS:
          case MAP:
          case SCALAR:
          case SEQ:
            return true;
        }
      return false;
    }
    var hasAnchor = (node) => (isScalar(node) || isCollection(node)) && !!node.anchor;
    exports.ALIAS = ALIAS;
    exports.DOC = DOC;
    exports.MAP = MAP;
    exports.NODE_TYPE = NODE_TYPE;
    exports.PAIR = PAIR;
    exports.SCALAR = SCALAR;
    exports.SEQ = SEQ;
    exports.hasAnchor = hasAnchor;
    exports.isAlias = isAlias;
    exports.isCollection = isCollection;
    exports.isDocument = isDocument;
    exports.isMap = isMap2;
    exports.isNode = isNode;
    exports.isPair = isPair;
    exports.isScalar = isScalar;
    exports.isSeq = isSeq;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/visit.js
var require_visit = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/visit.js"(exports) {
    "use strict";
    var identity = require_identity();
    var BREAK = Symbol("break visit");
    var SKIP = Symbol("skip children");
    var REMOVE = Symbol("remove node");
    function visit(node, visitor) {
      const visitor_ = initVisitor(visitor);
      if (identity.isDocument(node)) {
        const cd = visit_(null, node.contents, visitor_, Object.freeze([node]));
        if (cd === REMOVE)
          node.contents = null;
      } else
        visit_(null, node, visitor_, Object.freeze([]));
    }
    visit.BREAK = BREAK;
    visit.SKIP = SKIP;
    visit.REMOVE = REMOVE;
    function visit_(key, node, visitor, path) {
      const ctrl = callVisitor(key, node, visitor, path);
      if (identity.isNode(ctrl) || identity.isPair(ctrl)) {
        replaceNode(key, path, ctrl);
        return visit_(key, ctrl, visitor, path);
      }
      if (typeof ctrl !== "symbol") {
        if (identity.isCollection(node)) {
          path = Object.freeze(path.concat(node));
          for (let i = 0; i < node.items.length; ++i) {
            const ci = visit_(i, node.items[i], visitor, path);
            if (typeof ci === "number")
              i = ci - 1;
            else if (ci === BREAK)
              return BREAK;
            else if (ci === REMOVE) {
              node.items.splice(i, 1);
              i -= 1;
            }
          }
        } else if (identity.isPair(node)) {
          path = Object.freeze(path.concat(node));
          const ck = visit_("key", node.key, visitor, path);
          if (ck === BREAK)
            return BREAK;
          else if (ck === REMOVE)
            node.key = null;
          const cv = visit_("value", node.value, visitor, path);
          if (cv === BREAK)
            return BREAK;
          else if (cv === REMOVE)
            node.value = null;
        }
      }
      return ctrl;
    }
    async function visitAsync(node, visitor) {
      const visitor_ = initVisitor(visitor);
      if (identity.isDocument(node)) {
        const cd = await visitAsync_(null, node.contents, visitor_, Object.freeze([node]));
        if (cd === REMOVE)
          node.contents = null;
      } else
        await visitAsync_(null, node, visitor_, Object.freeze([]));
    }
    visitAsync.BREAK = BREAK;
    visitAsync.SKIP = SKIP;
    visitAsync.REMOVE = REMOVE;
    async function visitAsync_(key, node, visitor, path) {
      const ctrl = await callVisitor(key, node, visitor, path);
      if (identity.isNode(ctrl) || identity.isPair(ctrl)) {
        replaceNode(key, path, ctrl);
        return visitAsync_(key, ctrl, visitor, path);
      }
      if (typeof ctrl !== "symbol") {
        if (identity.isCollection(node)) {
          path = Object.freeze(path.concat(node));
          for (let i = 0; i < node.items.length; ++i) {
            const ci = await visitAsync_(i, node.items[i], visitor, path);
            if (typeof ci === "number")
              i = ci - 1;
            else if (ci === BREAK)
              return BREAK;
            else if (ci === REMOVE) {
              node.items.splice(i, 1);
              i -= 1;
            }
          }
        } else if (identity.isPair(node)) {
          path = Object.freeze(path.concat(node));
          const ck = await visitAsync_("key", node.key, visitor, path);
          if (ck === BREAK)
            return BREAK;
          else if (ck === REMOVE)
            node.key = null;
          const cv = await visitAsync_("value", node.value, visitor, path);
          if (cv === BREAK)
            return BREAK;
          else if (cv === REMOVE)
            node.value = null;
        }
      }
      return ctrl;
    }
    function initVisitor(visitor) {
      if (typeof visitor === "object" && (visitor.Collection || visitor.Node || visitor.Value)) {
        return Object.assign({
          Alias: visitor.Node,
          Map: visitor.Node,
          Scalar: visitor.Node,
          Seq: visitor.Node
        }, visitor.Value && {
          Map: visitor.Value,
          Scalar: visitor.Value,
          Seq: visitor.Value
        }, visitor.Collection && {
          Map: visitor.Collection,
          Seq: visitor.Collection
        }, visitor);
      }
      return visitor;
    }
    function callVisitor(key, node, visitor, path) {
      if (typeof visitor === "function")
        return visitor(key, node, path);
      if (identity.isMap(node))
        return visitor.Map?.(key, node, path);
      if (identity.isSeq(node))
        return visitor.Seq?.(key, node, path);
      if (identity.isPair(node))
        return visitor.Pair?.(key, node, path);
      if (identity.isScalar(node))
        return visitor.Scalar?.(key, node, path);
      if (identity.isAlias(node))
        return visitor.Alias?.(key, node, path);
      return void 0;
    }
    function replaceNode(key, path, node) {
      const parent = path[path.length - 1];
      if (identity.isCollection(parent)) {
        parent.items[key] = node;
      } else if (identity.isPair(parent)) {
        if (key === "key")
          parent.key = node;
        else
          parent.value = node;
      } else if (identity.isDocument(parent)) {
        parent.contents = node;
      } else {
        const pt = identity.isAlias(parent) ? "alias" : "scalar";
        throw new Error(`Cannot replace node with ${pt} parent`);
      }
    }
    exports.visit = visit;
    exports.visitAsync = visitAsync;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/doc/directives.js
var require_directives = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/doc/directives.js"(exports) {
    "use strict";
    var identity = require_identity();
    var visit = require_visit();
    var escapeChars = {
      "!": "%21",
      ",": "%2C",
      "[": "%5B",
      "]": "%5D",
      "{": "%7B",
      "}": "%7D"
    };
    var escapeTagName = (tn) => tn.replace(/[!,[\]{}]/g, (ch) => escapeChars[ch]);
    var Directives = class _Directives {
      constructor(yaml, tags) {
        this.docStart = null;
        this.docEnd = false;
        this.yaml = Object.assign({}, _Directives.defaultYaml, yaml);
        this.tags = Object.assign({}, _Directives.defaultTags, tags);
      }
      clone() {
        const copy = new _Directives(this.yaml, this.tags);
        copy.docStart = this.docStart;
        return copy;
      }
      /**
       * During parsing, get a Directives instance for the current document and
       * update the stream state according to the current version's spec.
       */
      atDocument() {
        const res = new _Directives(this.yaml, this.tags);
        switch (this.yaml.version) {
          case "1.1":
            this.atNextDocument = true;
            break;
          case "1.2":
            this.atNextDocument = false;
            this.yaml = {
              explicit: _Directives.defaultYaml.explicit,
              version: "1.2"
            };
            this.tags = Object.assign({}, _Directives.defaultTags);
            break;
        }
        return res;
      }
      /**
       * @param onError - May be called even if the action was successful
       * @returns `true` on success
       */
      add(line, onError) {
        if (this.atNextDocument) {
          this.yaml = { explicit: _Directives.defaultYaml.explicit, version: "1.1" };
          this.tags = Object.assign({}, _Directives.defaultTags);
          this.atNextDocument = false;
        }
        const parts = line.trim().split(/[ \t]+/);
        const name = parts.shift();
        switch (name) {
          case "%TAG": {
            if (parts.length !== 2) {
              onError(0, "%TAG directive should contain exactly two parts");
              if (parts.length < 2)
                return false;
            }
            const [handle, prefix] = parts;
            this.tags[handle] = prefix;
            return true;
          }
          case "%YAML": {
            this.yaml.explicit = true;
            if (parts.length !== 1) {
              onError(0, "%YAML directive should contain exactly one part");
              return false;
            }
            const [version] = parts;
            if (version === "1.1" || version === "1.2") {
              this.yaml.version = version;
              return true;
            } else {
              const isValid = /^\d+\.\d+$/.test(version);
              onError(6, `Unsupported YAML version ${version}`, isValid);
              return false;
            }
          }
          default:
            onError(0, `Unknown directive ${name}`, true);
            return false;
        }
      }
      /**
       * Resolves a tag, matching handles to those defined in %TAG directives.
       *
       * @returns Resolved tag, which may also be the non-specific tag `'!'` or a
       *   `'!local'` tag, or `null` if unresolvable.
       */
      tagName(source, onError) {
        if (source === "!")
          return "!";
        if (source[0] !== "!") {
          onError(`Not a valid tag: ${source}`);
          return null;
        }
        if (source[1] === "<") {
          const verbatim = source.slice(2, -1);
          if (verbatim === "!" || verbatim === "!!") {
            onError(`Verbatim tags aren't resolved, so ${source} is invalid.`);
            return null;
          }
          if (source[source.length - 1] !== ">")
            onError("Verbatim tags must end with a >");
          return verbatim;
        }
        const [, handle, suffix] = source.match(/^(.*!)([^!]*)$/s);
        if (!suffix)
          onError(`The ${source} tag has no suffix`);
        const prefix = this.tags[handle];
        if (prefix) {
          try {
            return prefix + decodeURIComponent(suffix);
          } catch (error) {
            onError(String(error));
            return null;
          }
        }
        if (handle === "!")
          return source;
        onError(`Could not resolve tag: ${source}`);
        return null;
      }
      /**
       * Given a fully resolved tag, returns its printable string form,
       * taking into account current tag prefixes and defaults.
       */
      tagString(tag) {
        for (const [handle, prefix] of Object.entries(this.tags)) {
          if (tag.startsWith(prefix))
            return handle + escapeTagName(tag.substring(prefix.length));
        }
        return tag[0] === "!" ? tag : `!<${tag}>`;
      }
      toString(doc) {
        const lines = this.yaml.explicit ? [`%YAML ${this.yaml.version || "1.2"}`] : [];
        const tagEntries = Object.entries(this.tags);
        let tagNames;
        if (doc && tagEntries.length > 0 && identity.isNode(doc.contents)) {
          const tags = {};
          visit.visit(doc.contents, (_key, node) => {
            if (identity.isNode(node) && node.tag)
              tags[node.tag] = true;
          });
          tagNames = Object.keys(tags);
        } else
          tagNames = [];
        for (const [handle, prefix] of tagEntries) {
          if (handle === "!!" && prefix === "tag:yaml.org,2002:")
            continue;
          if (!doc || tagNames.some((tn) => tn.startsWith(prefix)))
            lines.push(`%TAG ${handle} ${prefix}`);
        }
        return lines.join("\n");
      }
    };
    Directives.defaultYaml = { explicit: false, version: "1.2" };
    Directives.defaultTags = { "!!": "tag:yaml.org,2002:" };
    exports.Directives = Directives;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/doc/anchors.js
var require_anchors = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/doc/anchors.js"(exports) {
    "use strict";
    var identity = require_identity();
    var visit = require_visit();
    function anchorIsValid(anchor) {
      if (/[\x00-\x19\s,[\]{}]/.test(anchor)) {
        const sa = JSON.stringify(anchor);
        const msg = `Anchor must not contain whitespace or control characters: ${sa}`;
        throw new Error(msg);
      }
      return true;
    }
    function anchorNames(root) {
      const anchors = /* @__PURE__ */ new Set();
      visit.visit(root, {
        Value(_key, node) {
          if (node.anchor)
            anchors.add(node.anchor);
        }
      });
      return anchors;
    }
    function findNewAnchor(prefix, exclude) {
      for (let i = 1; true; ++i) {
        const name = `${prefix}${i}`;
        if (!exclude.has(name))
          return name;
      }
    }
    function createNodeAnchors(doc, prefix) {
      const aliasObjects = [];
      const sourceObjects = /* @__PURE__ */ new Map();
      let prevAnchors = null;
      return {
        onAnchor: (source) => {
          aliasObjects.push(source);
          prevAnchors ?? (prevAnchors = anchorNames(doc));
          const anchor = findNewAnchor(prefix, prevAnchors);
          prevAnchors.add(anchor);
          return anchor;
        },
        /**
         * With circular references, the source node is only resolved after all
         * of its child nodes are. This is why anchors are set only after all of
         * the nodes have been created.
         */
        setAnchors: () => {
          for (const source of aliasObjects) {
            const ref = sourceObjects.get(source);
            if (typeof ref === "object" && ref.anchor && (identity.isScalar(ref.node) || identity.isCollection(ref.node))) {
              ref.node.anchor = ref.anchor;
            } else {
              const error = new Error("Failed to resolve repeated object (this should not happen)");
              error.source = source;
              throw error;
            }
          }
        },
        sourceObjects
      };
    }
    exports.anchorIsValid = anchorIsValid;
    exports.anchorNames = anchorNames;
    exports.createNodeAnchors = createNodeAnchors;
    exports.findNewAnchor = findNewAnchor;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/doc/applyReviver.js
var require_applyReviver = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/doc/applyReviver.js"(exports) {
    "use strict";
    function applyReviver(reviver, obj, key, val) {
      if (val && typeof val === "object") {
        if (Array.isArray(val)) {
          for (let i = 0, len = val.length; i < len; ++i) {
            const v0 = val[i];
            const v1 = applyReviver(reviver, val, String(i), v0);
            if (v1 === void 0)
              delete val[i];
            else if (v1 !== v0)
              val[i] = v1;
          }
        } else if (val instanceof Map) {
          for (const k of Array.from(val.keys())) {
            const v0 = val.get(k);
            const v1 = applyReviver(reviver, val, k, v0);
            if (v1 === void 0)
              val.delete(k);
            else if (v1 !== v0)
              val.set(k, v1);
          }
        } else if (val instanceof Set) {
          for (const v0 of Array.from(val)) {
            const v1 = applyReviver(reviver, val, v0, v0);
            if (v1 === void 0)
              val.delete(v0);
            else if (v1 !== v0) {
              val.delete(v0);
              val.add(v1);
            }
          }
        } else {
          for (const [k, v0] of Object.entries(val)) {
            const v1 = applyReviver(reviver, val, k, v0);
            if (v1 === void 0)
              delete val[k];
            else if (v1 !== v0)
              val[k] = v1;
          }
        }
      }
      return reviver.call(obj, key, val);
    }
    exports.applyReviver = applyReviver;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/toJS.js
var require_toJS = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/toJS.js"(exports) {
    "use strict";
    var identity = require_identity();
    function toJS(value, arg, ctx) {
      if (Array.isArray(value))
        return value.map((v, i) => toJS(v, String(i), ctx));
      if (value && typeof value.toJSON === "function") {
        if (!ctx || !identity.hasAnchor(value))
          return value.toJSON(arg, ctx);
        const data = { aliasCount: 0, count: 1, res: void 0 };
        ctx.anchors.set(value, data);
        ctx.onCreate = (res2) => {
          data.res = res2;
          delete ctx.onCreate;
        };
        const res = value.toJSON(arg, ctx);
        if (ctx.onCreate)
          ctx.onCreate(res);
        return res;
      }
      if (typeof value === "bigint" && !ctx?.keep)
        return Number(value);
      return value;
    }
    exports.toJS = toJS;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/Node.js
var require_Node = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/Node.js"(exports) {
    "use strict";
    var applyReviver = require_applyReviver();
    var identity = require_identity();
    var toJS = require_toJS();
    var NodeBase = class {
      constructor(type) {
        Object.defineProperty(this, identity.NODE_TYPE, { value: type });
      }
      /** Create a copy of this node.  */
      clone() {
        const copy = Object.create(Object.getPrototypeOf(this), Object.getOwnPropertyDescriptors(this));
        if (this.range)
          copy.range = this.range.slice();
        return copy;
      }
      /** A plain JavaScript representation of this node. */
      toJS(doc, { mapAsMap, maxAliasCount, onAnchor, reviver } = {}) {
        if (!identity.isDocument(doc))
          throw new TypeError("A document argument is required");
        const ctx = {
          anchors: /* @__PURE__ */ new Map(),
          doc,
          keep: true,
          mapAsMap: mapAsMap === true,
          mapKeyWarned: false,
          maxAliasCount: typeof maxAliasCount === "number" ? maxAliasCount : 100
        };
        const res = toJS.toJS(this, "", ctx);
        if (typeof onAnchor === "function")
          for (const { count, res: res2 } of ctx.anchors.values())
            onAnchor(res2, count);
        return typeof reviver === "function" ? applyReviver.applyReviver(reviver, { "": res }, "", res) : res;
      }
    };
    exports.NodeBase = NodeBase;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/Alias.js
var require_Alias = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/Alias.js"(exports) {
    "use strict";
    var anchors = require_anchors();
    var visit = require_visit();
    var identity = require_identity();
    var Node = require_Node();
    var toJS = require_toJS();
    var Alias = class extends Node.NodeBase {
      constructor(source) {
        super(identity.ALIAS);
        this.source = source;
        Object.defineProperty(this, "tag", {
          set() {
            throw new Error("Alias nodes cannot have tags");
          }
        });
      }
      /**
       * Resolve the value of this alias within `doc`, finding the last
       * instance of the `source` anchor before this node.
       */
      resolve(doc, ctx) {
        if (ctx?.maxAliasCount === 0)
          throw new ReferenceError("Alias resolution is disabled");
        let nodes;
        if (ctx?.aliasResolveCache) {
          nodes = ctx.aliasResolveCache;
        } else {
          nodes = [];
          visit.visit(doc, {
            Node: (_key, node) => {
              if (identity.isAlias(node) || identity.hasAnchor(node))
                nodes.push(node);
            }
          });
          if (ctx)
            ctx.aliasResolveCache = nodes;
        }
        let found = void 0;
        for (const node of nodes) {
          if (node === this)
            break;
          if (node.anchor === this.source)
            found = node;
        }
        if (found && ctx) {
          const { anchors: anchors2, doc: doc2, maxAliasCount } = ctx;
          let data = anchors2.get(found);
          if (!data) {
            toJS.toJS(found, null, ctx);
            data = anchors2.get(found);
          }
          if (data?.res === void 0) {
            const msg = "This should not happen: Alias anchor was not resolved?";
            throw new ReferenceError(msg);
          }
          if (maxAliasCount >= 0) {
            data.count += 1;
            if (data.aliasCount === 0)
              data.aliasCount = getAliasCount(doc2, found, anchors2);
            if (data.count * data.aliasCount > maxAliasCount) {
              const msg = "Excessive alias count indicates a resource exhaustion attack";
              throw new ReferenceError(msg);
            }
          }
        }
        return found;
      }
      toJSON(_arg, ctx) {
        if (!ctx)
          return { source: this.source };
        const source = this.resolve(ctx.doc, ctx);
        if (!source) {
          const msg = `Unresolved alias (the anchor must be set before the alias): ${this.source}`;
          throw new ReferenceError(msg);
        }
        return ctx.anchors.get(source).res;
      }
      toString(ctx, _onComment, _onChompKeep) {
        const src = `*${this.source}`;
        if (ctx) {
          anchors.anchorIsValid(this.source);
          if (ctx.options.verifyAliasOrder && !ctx.anchors.has(this.source)) {
            const msg = `Unresolved alias (the anchor must be set before the alias): ${this.source}`;
            throw new Error(msg);
          }
          if (ctx.implicitKey)
            return `${src} `;
        }
        return src;
      }
    };
    function getAliasCount(doc, node, anchors2) {
      if (identity.isAlias(node)) {
        const source = node.resolve(doc);
        const anchor = anchors2 && source && anchors2.get(source);
        return anchor ? anchor.count * anchor.aliasCount : 0;
      } else if (identity.isCollection(node)) {
        let count = 0;
        for (const item of node.items) {
          const c = getAliasCount(doc, item, anchors2);
          if (c > count)
            count = c;
        }
        return count;
      } else if (identity.isPair(node)) {
        const kc = getAliasCount(doc, node.key, anchors2);
        const vc = getAliasCount(doc, node.value, anchors2);
        return Math.max(kc, vc);
      }
      return 1;
    }
    exports.Alias = Alias;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/Scalar.js
var require_Scalar = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/Scalar.js"(exports) {
    "use strict";
    var identity = require_identity();
    var Node = require_Node();
    var toJS = require_toJS();
    var isScalarValue = (value) => !value || typeof value !== "function" && typeof value !== "object";
    var Scalar = class extends Node.NodeBase {
      constructor(value) {
        super(identity.SCALAR);
        this.value = value;
      }
      toJSON(arg, ctx) {
        return ctx?.keep ? this.value : toJS.toJS(this.value, arg, ctx);
      }
      toString() {
        return String(this.value);
      }
    };
    Scalar.BLOCK_FOLDED = "BLOCK_FOLDED";
    Scalar.BLOCK_LITERAL = "BLOCK_LITERAL";
    Scalar.PLAIN = "PLAIN";
    Scalar.QUOTE_DOUBLE = "QUOTE_DOUBLE";
    Scalar.QUOTE_SINGLE = "QUOTE_SINGLE";
    exports.Scalar = Scalar;
    exports.isScalarValue = isScalarValue;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/doc/createNode.js
var require_createNode = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/doc/createNode.js"(exports) {
    "use strict";
    var Alias = require_Alias();
    var identity = require_identity();
    var Scalar = require_Scalar();
    var defaultTagPrefix = "tag:yaml.org,2002:";
    function findTagObject(value, tagName, tags) {
      if (tagName) {
        const match = tags.filter((t) => t.tag === tagName);
        const tagObj = match.find((t) => !t.format) ?? match[0];
        if (!tagObj)
          throw new Error(`Tag ${tagName} not found`);
        return tagObj;
      }
      return tags.find((t) => t.identify?.(value) && !t.format);
    }
    function createNode(value, tagName, ctx) {
      if (identity.isDocument(value))
        value = value.contents;
      if (identity.isNode(value))
        return value;
      if (identity.isPair(value)) {
        const map = ctx.schema[identity.MAP].createNode?.(ctx.schema, null, ctx);
        map.items.push(value);
        return map;
      }
      if (value instanceof String || value instanceof Number || value instanceof Boolean || typeof BigInt !== "undefined" && value instanceof BigInt) {
        value = value.valueOf();
      }
      const { aliasDuplicateObjects, onAnchor, onTagObj, schema, sourceObjects } = ctx;
      let ref = void 0;
      if (aliasDuplicateObjects && value && typeof value === "object") {
        ref = sourceObjects.get(value);
        if (ref) {
          ref.anchor ?? (ref.anchor = onAnchor(value));
          return new Alias.Alias(ref.anchor);
        } else {
          ref = { anchor: null, node: null };
          sourceObjects.set(value, ref);
        }
      }
      if (tagName?.startsWith("!!"))
        tagName = defaultTagPrefix + tagName.slice(2);
      let tagObj = findTagObject(value, tagName, schema.tags);
      if (!tagObj) {
        if (value && typeof value.toJSON === "function") {
          value = value.toJSON();
        }
        if (!value || typeof value !== "object") {
          const node2 = new Scalar.Scalar(value);
          if (ref)
            ref.node = node2;
          return node2;
        }
        tagObj = value instanceof Map ? schema[identity.MAP] : Symbol.iterator in Object(value) ? schema[identity.SEQ] : schema[identity.MAP];
      }
      if (onTagObj) {
        onTagObj(tagObj);
        delete ctx.onTagObj;
      }
      const node = tagObj?.createNode ? tagObj.createNode(ctx.schema, value, ctx) : typeof tagObj?.nodeClass?.from === "function" ? tagObj.nodeClass.from(ctx.schema, value, ctx) : new Scalar.Scalar(value);
      if (tagName)
        node.tag = tagName;
      else if (!tagObj.default)
        node.tag = tagObj.tag;
      if (ref)
        ref.node = node;
      return node;
    }
    exports.createNode = createNode;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/Collection.js
var require_Collection = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/Collection.js"(exports) {
    "use strict";
    var createNode = require_createNode();
    var identity = require_identity();
    var Node = require_Node();
    function collectionFromPath(schema, path, value) {
      let v = value;
      for (let i = path.length - 1; i >= 0; --i) {
        const k = path[i];
        if (typeof k === "number" && Number.isInteger(k) && k >= 0) {
          const a = [];
          a[k] = v;
          v = a;
        } else {
          v = /* @__PURE__ */ new Map([[k, v]]);
        }
      }
      return createNode.createNode(v, void 0, {
        aliasDuplicateObjects: false,
        keepUndefined: false,
        onAnchor: () => {
          throw new Error("This should not happen, please report a bug.");
        },
        schema,
        sourceObjects: /* @__PURE__ */ new Map()
      });
    }
    var isEmptyPath = (path) => path == null || typeof path === "object" && !!path[Symbol.iterator]().next().done;
    var Collection = class extends Node.NodeBase {
      constructor(type, schema) {
        super(type);
        Object.defineProperty(this, "schema", {
          value: schema,
          configurable: true,
          enumerable: false,
          writable: true
        });
      }
      /**
       * Create a copy of this collection.
       *
       * @param schema - If defined, overwrites the original's schema
       */
      clone(schema) {
        const copy = Object.create(Object.getPrototypeOf(this), Object.getOwnPropertyDescriptors(this));
        if (schema)
          copy.schema = schema;
        copy.items = copy.items.map((it) => identity.isNode(it) || identity.isPair(it) ? it.clone(schema) : it);
        if (this.range)
          copy.range = this.range.slice();
        return copy;
      }
      /**
       * Adds a value to the collection. For `!!map` and `!!omap` the value must
       * be a Pair instance or a `{ key, value }` object, which may not have a key
       * that already exists in the map.
       */
      addIn(path, value) {
        if (isEmptyPath(path))
          this.add(value);
        else {
          const [key, ...rest] = path;
          const node = this.get(key, true);
          if (identity.isCollection(node))
            node.addIn(rest, value);
          else if (node === void 0 && this.schema)
            this.set(key, collectionFromPath(this.schema, rest, value));
          else
            throw new Error(`Expected YAML collection at ${key}. Remaining path: ${rest}`);
        }
      }
      /**
       * Removes a value from the collection.
       * @returns `true` if the item was found and removed.
       */
      deleteIn(path) {
        const [key, ...rest] = path;
        if (rest.length === 0)
          return this.delete(key);
        const node = this.get(key, true);
        if (identity.isCollection(node))
          return node.deleteIn(rest);
        else
          throw new Error(`Expected YAML collection at ${key}. Remaining path: ${rest}`);
      }
      /**
       * Returns item at `key`, or `undefined` if not found. By default unwraps
       * scalar values from their surrounding node; to disable set `keepScalar` to
       * `true` (collections are always returned intact).
       */
      getIn(path, keepScalar) {
        const [key, ...rest] = path;
        const node = this.get(key, true);
        if (rest.length === 0)
          return !keepScalar && identity.isScalar(node) ? node.value : node;
        else
          return identity.isCollection(node) ? node.getIn(rest, keepScalar) : void 0;
      }
      hasAllNullValues(allowScalar) {
        return this.items.every((node) => {
          if (!identity.isPair(node))
            return false;
          const n = node.value;
          return n == null || allowScalar && identity.isScalar(n) && n.value == null && !n.commentBefore && !n.comment && !n.tag;
        });
      }
      /**
       * Checks if the collection includes a value with the key `key`.
       */
      hasIn(path) {
        const [key, ...rest] = path;
        if (rest.length === 0)
          return this.has(key);
        const node = this.get(key, true);
        return identity.isCollection(node) ? node.hasIn(rest) : false;
      }
      /**
       * Sets a value in this collection. For `!!set`, `value` needs to be a
       * boolean to add/remove the item from the set.
       */
      setIn(path, value) {
        const [key, ...rest] = path;
        if (rest.length === 0) {
          this.set(key, value);
        } else {
          const node = this.get(key, true);
          if (identity.isCollection(node))
            node.setIn(rest, value);
          else if (node === void 0 && this.schema)
            this.set(key, collectionFromPath(this.schema, rest, value));
          else
            throw new Error(`Expected YAML collection at ${key}. Remaining path: ${rest}`);
        }
      }
    };
    exports.Collection = Collection;
    exports.collectionFromPath = collectionFromPath;
    exports.isEmptyPath = isEmptyPath;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyComment.js
var require_stringifyComment = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyComment.js"(exports) {
    "use strict";
    var stringifyComment = (str2) => str2.replace(/^(?!$)(?: $)?/gm, "#");
    function indentComment(comment, indent) {
      if (/^\n+$/.test(comment))
        return comment.substring(1);
      return indent ? comment.replace(/^(?! *$)/gm, indent) : comment;
    }
    var lineComment = (str2, indent, comment) => str2.endsWith("\n") ? indentComment(comment, indent) : comment.includes("\n") ? "\n" + indentComment(comment, indent) : (str2.endsWith(" ") ? "" : " ") + comment;
    exports.indentComment = indentComment;
    exports.lineComment = lineComment;
    exports.stringifyComment = stringifyComment;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/foldFlowLines.js
var require_foldFlowLines = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/foldFlowLines.js"(exports) {
    "use strict";
    var FOLD_FLOW = "flow";
    var FOLD_BLOCK = "block";
    var FOLD_QUOTED = "quoted";
    function foldFlowLines(text, indent, mode = "flow", { indentAtStart, lineWidth = 80, minContentWidth = 20, onFold, onOverflow } = {}) {
      if (!lineWidth || lineWidth < 0)
        return text;
      if (lineWidth < minContentWidth)
        minContentWidth = 0;
      const endStep = Math.max(1 + minContentWidth, 1 + lineWidth - indent.length);
      if (text.length <= endStep)
        return text;
      const folds = [];
      const escapedFolds = {};
      let end = lineWidth - indent.length;
      if (typeof indentAtStart === "number") {
        if (indentAtStart > lineWidth - Math.max(2, minContentWidth))
          folds.push(0);
        else
          end = lineWidth - indentAtStart;
      }
      let split = void 0;
      let prev = void 0;
      let overflow = false;
      let i = -1;
      let escStart = -1;
      let escEnd = -1;
      if (mode === FOLD_BLOCK) {
        i = consumeMoreIndentedLines(text, i, indent.length);
        if (i !== -1)
          end = i + endStep;
      }
      for (let ch; ch = text[i += 1]; ) {
        if (mode === FOLD_QUOTED && ch === "\\") {
          escStart = i;
          switch (text[i + 1]) {
            case "x":
              i += 3;
              break;
            case "u":
              i += 5;
              break;
            case "U":
              i += 9;
              break;
            default:
              i += 1;
          }
          escEnd = i;
        }
        if (ch === "\n") {
          if (mode === FOLD_BLOCK)
            i = consumeMoreIndentedLines(text, i, indent.length);
          end = i + indent.length + endStep;
          split = void 0;
        } else {
          if (ch === " " && prev && prev !== " " && prev !== "\n" && prev !== "	") {
            const next = text[i + 1];
            if (next && next !== " " && next !== "\n" && next !== "	")
              split = i;
          }
          if (i >= end) {
            if (split) {
              folds.push(split);
              end = split + endStep;
              split = void 0;
            } else if (mode === FOLD_QUOTED) {
              while (prev === " " || prev === "	") {
                prev = ch;
                ch = text[i += 1];
                overflow = true;
              }
              const j = i > escEnd + 1 ? i - 2 : escStart - 1;
              if (escapedFolds[j])
                return text;
              folds.push(j);
              escapedFolds[j] = true;
              end = j + endStep;
              split = void 0;
            } else {
              overflow = true;
            }
          }
        }
        prev = ch;
      }
      if (overflow && onOverflow)
        onOverflow();
      if (folds.length === 0)
        return text;
      if (onFold)
        onFold();
      let res = text.slice(0, folds[0]);
      for (let i2 = 0; i2 < folds.length; ++i2) {
        const fold = folds[i2];
        const end2 = folds[i2 + 1] || text.length;
        if (fold === 0)
          res = `
${indent}${text.slice(0, end2)}`;
        else {
          if (mode === FOLD_QUOTED && escapedFolds[fold])
            res += `${text[fold]}\\`;
          res += `
${indent}${text.slice(fold + 1, end2)}`;
        }
      }
      return res;
    }
    function consumeMoreIndentedLines(text, i, indent) {
      let end = i;
      let start = i + 1;
      let ch = text[start];
      while (ch === " " || ch === "	") {
        if (i < start + indent) {
          ch = text[++i];
        } else {
          do {
            ch = text[++i];
          } while (ch && ch !== "\n");
          end = i;
          start = i + 1;
          ch = text[start];
        }
      }
      return end;
    }
    exports.FOLD_BLOCK = FOLD_BLOCK;
    exports.FOLD_FLOW = FOLD_FLOW;
    exports.FOLD_QUOTED = FOLD_QUOTED;
    exports.foldFlowLines = foldFlowLines;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyString.js
var require_stringifyString = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyString.js"(exports) {
    "use strict";
    var Scalar = require_Scalar();
    var foldFlowLines = require_foldFlowLines();
    var getFoldOptions = (ctx, isBlock) => ({
      indentAtStart: isBlock ? ctx.indent.length : ctx.indentAtStart,
      lineWidth: ctx.options.lineWidth,
      minContentWidth: ctx.options.minContentWidth
    });
    var containsDocumentMarker = (str2) => /^(%|---|\.\.\.)/m.test(str2);
    function lineLengthOverLimit(str2, lineWidth, indentLength) {
      if (!lineWidth || lineWidth < 0)
        return false;
      const limit = lineWidth - indentLength;
      const strLen = str2.length;
      if (strLen <= limit)
        return false;
      for (let i = 0, start = 0; i < strLen; ++i) {
        if (str2[i] === "\n") {
          if (i - start > limit)
            return true;
          start = i + 1;
          if (strLen - start <= limit)
            return false;
        }
      }
      return true;
    }
    function doubleQuotedString(value, ctx) {
      const json = JSON.stringify(value);
      if (ctx.options.doubleQuotedAsJSON)
        return json;
      const { implicitKey } = ctx;
      const minMultiLineLength = ctx.options.doubleQuotedMinMultiLineLength;
      const indent = ctx.indent || (containsDocumentMarker(value) ? "  " : "");
      let str2 = "";
      let start = 0;
      for (let i = 0, ch = json[i]; ch; ch = json[++i]) {
        if (ch === " " && json[i + 1] === "\\" && json[i + 2] === "n") {
          str2 += json.slice(start, i) + "\\ ";
          i += 1;
          start = i;
          ch = "\\";
        }
        if (ch === "\\")
          switch (json[i + 1]) {
            case "u":
              {
                str2 += json.slice(start, i);
                const code = json.substr(i + 2, 4);
                switch (code) {
                  case "0000":
                    str2 += "\\0";
                    break;
                  case "0007":
                    str2 += "\\a";
                    break;
                  case "000b":
                    str2 += "\\v";
                    break;
                  case "001b":
                    str2 += "\\e";
                    break;
                  case "0085":
                    str2 += "\\N";
                    break;
                  case "00a0":
                    str2 += "\\_";
                    break;
                  case "2028":
                    str2 += "\\L";
                    break;
                  case "2029":
                    str2 += "\\P";
                    break;
                  default:
                    if (code.substr(0, 2) === "00")
                      str2 += "\\x" + code.substr(2);
                    else
                      str2 += json.substr(i, 6);
                }
                i += 5;
                start = i + 1;
              }
              break;
            case "n":
              if (implicitKey || json[i + 2] === '"' || json.length < minMultiLineLength) {
                i += 1;
              } else {
                str2 += json.slice(start, i) + "\n\n";
                while (json[i + 2] === "\\" && json[i + 3] === "n" && json[i + 4] !== '"') {
                  str2 += "\n";
                  i += 2;
                }
                str2 += indent;
                if (json[i + 2] === " ")
                  str2 += "\\";
                i += 1;
                start = i + 1;
              }
              break;
            default:
              i += 1;
          }
      }
      str2 = start ? str2 + json.slice(start) : json;
      return implicitKey ? str2 : foldFlowLines.foldFlowLines(str2, indent, foldFlowLines.FOLD_QUOTED, getFoldOptions(ctx, false));
    }
    function singleQuotedString(value, ctx) {
      if (ctx.options.singleQuote === false || ctx.implicitKey && value.includes("\n") || /[ \t]\n|\n[ \t]/.test(value))
        return doubleQuotedString(value, ctx);
      const indent = ctx.indent || (containsDocumentMarker(value) ? "  " : "");
      const res = "'" + value.replace(/'/g, "''").replace(/\n+/g, `$&
${indent}`) + "'";
      return ctx.implicitKey ? res : foldFlowLines.foldFlowLines(res, indent, foldFlowLines.FOLD_FLOW, getFoldOptions(ctx, false));
    }
    function quotedString(value, ctx) {
      const { singleQuote } = ctx.options;
      let qs;
      if (singleQuote === false)
        qs = doubleQuotedString;
      else {
        const hasDouble = value.includes('"');
        const hasSingle = value.includes("'");
        if (hasDouble && !hasSingle)
          qs = singleQuotedString;
        else if (hasSingle && !hasDouble)
          qs = doubleQuotedString;
        else
          qs = singleQuote ? singleQuotedString : doubleQuotedString;
      }
      return qs(value, ctx);
    }
    var blockEndNewlines;
    try {
      blockEndNewlines = new RegExp("(^|(?<!\n))\n+(?!\n|$)", "g");
    } catch {
      blockEndNewlines = /\n+(?!\n|$)/g;
    }
    function blockString({ comment, type, value }, ctx, onComment, onChompKeep) {
      const { blockQuote, commentString, lineWidth } = ctx.options;
      if (!blockQuote || /\n[\t ]+$/.test(value)) {
        return quotedString(value, ctx);
      }
      const indent = ctx.indent || (ctx.forceBlockIndent || containsDocumentMarker(value) ? "  " : "");
      const literal = blockQuote === "literal" ? true : blockQuote === "folded" || type === Scalar.Scalar.BLOCK_FOLDED ? false : type === Scalar.Scalar.BLOCK_LITERAL ? true : !lineLengthOverLimit(value, lineWidth, indent.length);
      if (!value)
        return literal ? "|\n" : ">\n";
      let chomp;
      let endStart;
      for (endStart = value.length; endStart > 0; --endStart) {
        const ch = value[endStart - 1];
        if (ch !== "\n" && ch !== "	" && ch !== " ")
          break;
      }
      let end = value.substring(endStart);
      const endNlPos = end.indexOf("\n");
      if (endNlPos === -1) {
        chomp = "-";
      } else if (value === end || endNlPos !== end.length - 1) {
        chomp = "+";
        if (onChompKeep)
          onChompKeep();
      } else {
        chomp = "";
      }
      if (end) {
        value = value.slice(0, -end.length);
        if (end[end.length - 1] === "\n")
          end = end.slice(0, -1);
        end = end.replace(blockEndNewlines, `$&${indent}`);
      }
      let startWithSpace = false;
      let startEnd;
      let startNlPos = -1;
      for (startEnd = 0; startEnd < value.length; ++startEnd) {
        const ch = value[startEnd];
        if (ch === " ")
          startWithSpace = true;
        else if (ch === "\n")
          startNlPos = startEnd;
        else
          break;
      }
      let start = value.substring(0, startNlPos < startEnd ? startNlPos + 1 : startEnd);
      if (start) {
        value = value.substring(start.length);
        start = start.replace(/\n+/g, `$&${indent}`);
      }
      const indentSize = indent ? "2" : "1";
      let header = (startWithSpace ? indentSize : "") + chomp;
      if (comment) {
        header += " " + commentString(comment.replace(/ ?[\r\n]+/g, " "));
        if (onComment)
          onComment();
      }
      if (!literal) {
        const foldedValue = value.replace(/\n+/g, "\n$&").replace(/(?:^|\n)([\t ].*)(?:([\n\t ]*)\n(?![\n\t ]))?/g, "$1$2").replace(/\n+/g, `$&${indent}`);
        let literalFallback = false;
        const foldOptions = getFoldOptions(ctx, true);
        if (blockQuote !== "folded" && type !== Scalar.Scalar.BLOCK_FOLDED) {
          foldOptions.onOverflow = () => {
            literalFallback = true;
          };
        }
        const body = foldFlowLines.foldFlowLines(`${start}${foldedValue}${end}`, indent, foldFlowLines.FOLD_BLOCK, foldOptions);
        if (!literalFallback)
          return `>${header}
${indent}${body}`;
      }
      value = value.replace(/\n+/g, `$&${indent}`);
      return `|${header}
${indent}${start}${value}${end}`;
    }
    function plainString(item, ctx, onComment, onChompKeep) {
      const { type, value } = item;
      const { actualString, implicitKey, indent, indentStep, inFlow } = ctx;
      if (implicitKey && value.includes("\n") || inFlow && /[[\]{},]/.test(value)) {
        return quotedString(value, ctx);
      }
      if (/^[\n\t ,[\]{}#&*!|>'"%@`]|^[?-]$|^[?-][ \t]|[\n:][ \t]|[ \t]\n|[\n\t ]#|[\n\t :]$/.test(value)) {
        return implicitKey || inFlow || !value.includes("\n") ? quotedString(value, ctx) : blockString(item, ctx, onComment, onChompKeep);
      }
      if (!implicitKey && !inFlow && type !== Scalar.Scalar.PLAIN && value.includes("\n")) {
        return blockString(item, ctx, onComment, onChompKeep);
      }
      if (containsDocumentMarker(value)) {
        if (indent === "") {
          ctx.forceBlockIndent = true;
          return blockString(item, ctx, onComment, onChompKeep);
        } else if (implicitKey && indent === indentStep) {
          return quotedString(value, ctx);
        }
      }
      const str2 = value.replace(/\n+/g, `$&
${indent}`);
      if (actualString) {
        const test = (tag) => tag.default && tag.tag !== "tag:yaml.org,2002:str" && tag.test?.test(str2);
        const { compat, tags } = ctx.doc.schema;
        if (tags.some(test) || compat?.some(test))
          return quotedString(value, ctx);
      }
      return implicitKey ? str2 : foldFlowLines.foldFlowLines(str2, indent, foldFlowLines.FOLD_FLOW, getFoldOptions(ctx, false));
    }
    function stringifyString(item, ctx, onComment, onChompKeep) {
      const { implicitKey, inFlow } = ctx;
      const ss = typeof item.value === "string" ? item : Object.assign({}, item, { value: String(item.value) });
      let { type } = item;
      if (type !== Scalar.Scalar.QUOTE_DOUBLE) {
        if (/[\x00-\x08\x0b-\x1f\x7f-\x9f\u{D800}-\u{DFFF}]/u.test(ss.value))
          type = Scalar.Scalar.QUOTE_DOUBLE;
      }
      const _stringify = (_type) => {
        switch (_type) {
          case Scalar.Scalar.BLOCK_FOLDED:
          case Scalar.Scalar.BLOCK_LITERAL:
            return implicitKey || inFlow ? quotedString(ss.value, ctx) : blockString(ss, ctx, onComment, onChompKeep);
          case Scalar.Scalar.QUOTE_DOUBLE:
            return doubleQuotedString(ss.value, ctx);
          case Scalar.Scalar.QUOTE_SINGLE:
            return singleQuotedString(ss.value, ctx);
          case Scalar.Scalar.PLAIN:
            return plainString(ss, ctx, onComment, onChompKeep);
          default:
            return null;
        }
      };
      let res = _stringify(type);
      if (res === null) {
        const { defaultKeyType, defaultStringType } = ctx.options;
        const t = implicitKey && defaultKeyType || defaultStringType;
        res = _stringify(t);
        if (res === null)
          throw new Error(`Unsupported default string type ${t}`);
      }
      return res;
    }
    exports.stringifyString = stringifyString;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringify.js
var require_stringify = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringify.js"(exports) {
    "use strict";
    var anchors = require_anchors();
    var identity = require_identity();
    var stringifyComment = require_stringifyComment();
    var stringifyString = require_stringifyString();
    function createStringifyContext(doc, options) {
      const opt = Object.assign({
        blockQuote: true,
        commentString: stringifyComment.stringifyComment,
        defaultKeyType: null,
        defaultStringType: "PLAIN",
        directives: null,
        doubleQuotedAsJSON: false,
        doubleQuotedMinMultiLineLength: 40,
        falseStr: "false",
        flowCollectionPadding: true,
        indentSeq: true,
        lineWidth: 80,
        minContentWidth: 20,
        nullStr: "null",
        simpleKeys: false,
        singleQuote: null,
        trailingComma: false,
        trueStr: "true",
        verifyAliasOrder: true
      }, doc.schema.toStringOptions, options);
      let inFlow;
      switch (opt.collectionStyle) {
        case "block":
          inFlow = false;
          break;
        case "flow":
          inFlow = true;
          break;
        default:
          inFlow = null;
      }
      return {
        anchors: /* @__PURE__ */ new Set(),
        doc,
        flowCollectionPadding: opt.flowCollectionPadding ? " " : "",
        indent: "",
        indentStep: typeof opt.indent === "number" ? " ".repeat(opt.indent) : "  ",
        inFlow,
        options: opt
      };
    }
    function getTagObject(tags, item) {
      if (item.tag) {
        const match = tags.filter((t) => t.tag === item.tag);
        if (match.length > 0)
          return match.find((t) => t.format === item.format) ?? match[0];
      }
      let tagObj = void 0;
      let obj;
      if (identity.isScalar(item)) {
        obj = item.value;
        let match = tags.filter((t) => t.identify?.(obj));
        if (match.length > 1) {
          const testMatch = match.filter((t) => t.test);
          if (testMatch.length > 0)
            match = testMatch;
        }
        tagObj = match.find((t) => t.format === item.format) ?? match.find((t) => !t.format);
      } else {
        obj = item;
        tagObj = tags.find((t) => t.nodeClass && obj instanceof t.nodeClass);
      }
      if (!tagObj) {
        const name = obj?.constructor?.name ?? (obj === null ? "null" : typeof obj);
        throw new Error(`Tag not resolved for ${name} value`);
      }
      return tagObj;
    }
    function stringifyProps(node, tagObj, { anchors: anchors$1, doc }) {
      if (!doc.directives)
        return "";
      const props = [];
      const anchor = (identity.isScalar(node) || identity.isCollection(node)) && node.anchor;
      if (anchor && anchors.anchorIsValid(anchor)) {
        anchors$1.add(anchor);
        props.push(`&${anchor}`);
      }
      const tag = node.tag ?? (tagObj.default ? null : tagObj.tag);
      if (tag)
        props.push(doc.directives.tagString(tag));
      return props.join(" ");
    }
    function stringify(item, ctx, onComment, onChompKeep) {
      if (identity.isPair(item))
        return item.toString(ctx, onComment, onChompKeep);
      if (identity.isAlias(item)) {
        if (ctx.doc.directives)
          return item.toString(ctx);
        if (ctx.resolvedAliases?.has(item)) {
          throw new TypeError(`Cannot stringify circular structure without alias nodes`);
        } else {
          if (ctx.resolvedAliases)
            ctx.resolvedAliases.add(item);
          else
            ctx.resolvedAliases = /* @__PURE__ */ new Set([item]);
          item = item.resolve(ctx.doc);
        }
      }
      let tagObj = void 0;
      const node = identity.isNode(item) ? item : ctx.doc.createNode(item, { onTagObj: (o) => tagObj = o });
      tagObj ?? (tagObj = getTagObject(ctx.doc.schema.tags, node));
      const props = stringifyProps(node, tagObj, ctx);
      if (props.length > 0)
        ctx.indentAtStart = (ctx.indentAtStart ?? 0) + props.length + 1;
      const str2 = typeof tagObj.stringify === "function" ? tagObj.stringify(node, ctx, onComment, onChompKeep) : identity.isScalar(node) ? stringifyString.stringifyString(node, ctx, onComment, onChompKeep) : node.toString(ctx, onComment, onChompKeep);
      if (!props)
        return str2;
      return identity.isScalar(node) || str2[0] === "{" || str2[0] === "[" ? `${props} ${str2}` : `${props}
${ctx.indent}${str2}`;
    }
    exports.createStringifyContext = createStringifyContext;
    exports.stringify = stringify;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyPair.js
var require_stringifyPair = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyPair.js"(exports) {
    "use strict";
    var identity = require_identity();
    var Scalar = require_Scalar();
    var stringify = require_stringify();
    var stringifyComment = require_stringifyComment();
    function stringifyPair({ key, value }, ctx, onComment, onChompKeep) {
      const { allNullValues, doc, indent, indentStep, options: { commentString, indentSeq, simpleKeys } } = ctx;
      let keyComment = identity.isNode(key) && key.comment || null;
      if (simpleKeys) {
        if (keyComment) {
          throw new Error("With simple keys, key nodes cannot have comments");
        }
        if (identity.isCollection(key) || !identity.isNode(key) && typeof key === "object") {
          const msg = "With simple keys, collection cannot be used as a key value";
          throw new Error(msg);
        }
      }
      let explicitKey = !simpleKeys && (!key || keyComment && value == null && !ctx.inFlow || identity.isCollection(key) || (identity.isScalar(key) ? key.type === Scalar.Scalar.BLOCK_FOLDED || key.type === Scalar.Scalar.BLOCK_LITERAL : typeof key === "object"));
      ctx = Object.assign({}, ctx, {
        allNullValues: false,
        implicitKey: !explicitKey && (simpleKeys || !allNullValues),
        indent: indent + indentStep
      });
      let keyCommentDone = false;
      let chompKeep = false;
      let str2 = stringify.stringify(key, ctx, () => keyCommentDone = true, () => chompKeep = true);
      if (!explicitKey && !ctx.inFlow && str2.length > 1024) {
        if (simpleKeys)
          throw new Error("With simple keys, single line scalar must not span more than 1024 characters");
        explicitKey = true;
      }
      if (ctx.inFlow) {
        if (allNullValues || value == null) {
          if (keyCommentDone && onComment)
            onComment();
          return str2 === "" ? "?" : explicitKey ? `? ${str2}` : str2;
        }
      } else if (allNullValues && !simpleKeys || value == null && explicitKey) {
        str2 = `? ${str2}`;
        if (keyComment && !keyCommentDone) {
          str2 += stringifyComment.lineComment(str2, ctx.indent, commentString(keyComment));
        } else if (chompKeep && onChompKeep)
          onChompKeep();
        return str2;
      }
      if (keyCommentDone)
        keyComment = null;
      if (explicitKey) {
        if (keyComment)
          str2 += stringifyComment.lineComment(str2, ctx.indent, commentString(keyComment));
        str2 = `? ${str2}
${indent}:`;
      } else {
        str2 = `${str2}:`;
        if (keyComment)
          str2 += stringifyComment.lineComment(str2, ctx.indent, commentString(keyComment));
      }
      let vsb, vcb, valueComment;
      if (identity.isNode(value)) {
        vsb = !!value.spaceBefore;
        vcb = value.commentBefore;
        valueComment = value.comment;
      } else {
        vsb = false;
        vcb = null;
        valueComment = null;
        if (value && typeof value === "object")
          value = doc.createNode(value);
      }
      ctx.implicitKey = false;
      if (!explicitKey && !keyComment && identity.isScalar(value))
        ctx.indentAtStart = str2.length + 1;
      chompKeep = false;
      if (!indentSeq && indentStep.length >= 2 && !ctx.inFlow && !explicitKey && identity.isSeq(value) && !value.flow && !value.tag && !value.anchor) {
        ctx.indent = ctx.indent.substring(2);
      }
      let valueCommentDone = false;
      const valueStr = stringify.stringify(value, ctx, () => valueCommentDone = true, () => chompKeep = true);
      let ws = " ";
      if (keyComment || vsb || vcb) {
        ws = vsb ? "\n" : "";
        if (vcb) {
          const cs = commentString(vcb);
          ws += `
${stringifyComment.indentComment(cs, ctx.indent)}`;
        }
        if (valueStr === "" && !ctx.inFlow) {
          if (ws === "\n" && valueComment)
            ws = "\n\n";
        } else {
          ws += `
${ctx.indent}`;
        }
      } else if (!explicitKey && identity.isCollection(value)) {
        const vs0 = valueStr[0];
        const nl0 = valueStr.indexOf("\n");
        const hasNewline = nl0 !== -1;
        const flow = ctx.inFlow ?? value.flow ?? value.items.length === 0;
        if (hasNewline || !flow) {
          let hasPropsLine = false;
          if (hasNewline && (vs0 === "&" || vs0 === "!")) {
            let sp0 = valueStr.indexOf(" ");
            if (vs0 === "&" && sp0 !== -1 && sp0 < nl0 && valueStr[sp0 + 1] === "!") {
              sp0 = valueStr.indexOf(" ", sp0 + 1);
            }
            if (sp0 === -1 || nl0 < sp0)
              hasPropsLine = true;
          }
          if (!hasPropsLine)
            ws = `
${ctx.indent}`;
        }
      } else if (valueStr === "" || valueStr[0] === "\n") {
        ws = "";
      }
      str2 += ws + valueStr;
      if (ctx.inFlow) {
        if (valueCommentDone && onComment)
          onComment();
      } else if (valueComment && !valueCommentDone) {
        str2 += stringifyComment.lineComment(str2, ctx.indent, commentString(valueComment));
      } else if (chompKeep && onChompKeep) {
        onChompKeep();
      }
      return str2;
    }
    exports.stringifyPair = stringifyPair;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/log.js
var require_log = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/log.js"(exports) {
    "use strict";
    var node_process = __require("process");
    function debug(logLevel, ...messages) {
      if (logLevel === "debug")
        console.log(...messages);
    }
    function warn(logLevel, warning) {
      if (logLevel === "debug" || logLevel === "warn") {
        if (typeof node_process.emitWarning === "function")
          node_process.emitWarning(warning);
        else
          console.warn(warning);
      }
    }
    exports.debug = debug;
    exports.warn = warn;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/merge.js
var require_merge = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/merge.js"(exports) {
    "use strict";
    var identity = require_identity();
    var Scalar = require_Scalar();
    var MERGE_KEY = "<<";
    var merge = {
      identify: (value) => value === MERGE_KEY || typeof value === "symbol" && value.description === MERGE_KEY,
      default: "key",
      tag: "tag:yaml.org,2002:merge",
      test: /^<<$/,
      resolve: () => Object.assign(new Scalar.Scalar(Symbol(MERGE_KEY)), {
        addToJSMap: addMergeToJSMap
      }),
      stringify: () => MERGE_KEY
    };
    var isMergeKey = (ctx, key) => (merge.identify(key) || identity.isScalar(key) && (!key.type || key.type === Scalar.Scalar.PLAIN) && merge.identify(key.value)) && ctx?.doc.schema.tags.some((tag) => tag.tag === merge.tag && tag.default);
    function addMergeToJSMap(ctx, map, value) {
      const source = resolveAliasValue(ctx, value);
      if (identity.isSeq(source))
        for (const it of source.items)
          mergeValue(ctx, map, it);
      else if (Array.isArray(source))
        for (const it of source)
          mergeValue(ctx, map, it);
      else
        mergeValue(ctx, map, source);
    }
    function mergeValue(ctx, map, value) {
      const source = resolveAliasValue(ctx, value);
      if (!identity.isMap(source))
        throw new Error("Merge sources must be maps or map aliases");
      const srcMap = source.toJSON(null, ctx, Map);
      for (const [key, value2] of srcMap) {
        if (map instanceof Map) {
          if (!map.has(key))
            map.set(key, value2);
        } else if (map instanceof Set) {
          map.add(key);
        } else if (!Object.prototype.hasOwnProperty.call(map, key)) {
          Object.defineProperty(map, key, {
            value: value2,
            writable: true,
            enumerable: true,
            configurable: true
          });
        }
      }
      return map;
    }
    function resolveAliasValue(ctx, value) {
      return ctx && identity.isAlias(value) ? value.resolve(ctx.doc, ctx) : value;
    }
    exports.addMergeToJSMap = addMergeToJSMap;
    exports.isMergeKey = isMergeKey;
    exports.merge = merge;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/addPairToJSMap.js
var require_addPairToJSMap = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/addPairToJSMap.js"(exports) {
    "use strict";
    var log = require_log();
    var merge = require_merge();
    var stringify = require_stringify();
    var identity = require_identity();
    var toJS = require_toJS();
    function addPairToJSMap(ctx, map, { key, value }) {
      if (identity.isNode(key) && key.addToJSMap)
        key.addToJSMap(ctx, map, value);
      else if (merge.isMergeKey(ctx, key))
        merge.addMergeToJSMap(ctx, map, value);
      else {
        const jsKey = toJS.toJS(key, "", ctx);
        if (map instanceof Map) {
          map.set(jsKey, toJS.toJS(value, jsKey, ctx));
        } else if (map instanceof Set) {
          map.add(jsKey);
        } else {
          const stringKey = stringifyKey(key, jsKey, ctx);
          const jsValue = toJS.toJS(value, stringKey, ctx);
          if (stringKey in map)
            Object.defineProperty(map, stringKey, {
              value: jsValue,
              writable: true,
              enumerable: true,
              configurable: true
            });
          else
            map[stringKey] = jsValue;
        }
      }
      return map;
    }
    function stringifyKey(key, jsKey, ctx) {
      if (jsKey === null)
        return "";
      if (typeof jsKey !== "object")
        return String(jsKey);
      if (identity.isNode(key) && ctx?.doc) {
        const strCtx = stringify.createStringifyContext(ctx.doc, {});
        strCtx.anchors = /* @__PURE__ */ new Set();
        for (const node of ctx.anchors.keys())
          strCtx.anchors.add(node.anchor);
        strCtx.inFlow = true;
        strCtx.inStringifyKey = true;
        const strKey = key.toString(strCtx);
        if (!ctx.mapKeyWarned) {
          let jsonStr = JSON.stringify(strKey);
          if (jsonStr.length > 40)
            jsonStr = jsonStr.substring(0, 36) + '..."';
          log.warn(ctx.doc.options.logLevel, `Keys with collection values will be stringified due to JS Object restrictions: ${jsonStr}. Set mapAsMap: true to use object keys.`);
          ctx.mapKeyWarned = true;
        }
        return strKey;
      }
      return JSON.stringify(jsKey);
    }
    exports.addPairToJSMap = addPairToJSMap;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/Pair.js
var require_Pair = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/Pair.js"(exports) {
    "use strict";
    var createNode = require_createNode();
    var stringifyPair = require_stringifyPair();
    var addPairToJSMap = require_addPairToJSMap();
    var identity = require_identity();
    function createPair(key, value, ctx) {
      const k = createNode.createNode(key, void 0, ctx);
      const v = createNode.createNode(value, void 0, ctx);
      return new Pair(k, v);
    }
    var Pair = class _Pair {
      constructor(key, value = null) {
        Object.defineProperty(this, identity.NODE_TYPE, { value: identity.PAIR });
        this.key = key;
        this.value = value;
      }
      clone(schema) {
        let { key, value } = this;
        if (identity.isNode(key))
          key = key.clone(schema);
        if (identity.isNode(value))
          value = value.clone(schema);
        return new _Pair(key, value);
      }
      toJSON(_, ctx) {
        const pair = ctx?.mapAsMap ? /* @__PURE__ */ new Map() : {};
        return addPairToJSMap.addPairToJSMap(ctx, pair, this);
      }
      toString(ctx, onComment, onChompKeep) {
        return ctx?.doc ? stringifyPair.stringifyPair(this, ctx, onComment, onChompKeep) : JSON.stringify(this);
      }
    };
    exports.Pair = Pair;
    exports.createPair = createPair;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyCollection.js
var require_stringifyCollection = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyCollection.js"(exports) {
    "use strict";
    var identity = require_identity();
    var stringify = require_stringify();
    var stringifyComment = require_stringifyComment();
    function stringifyCollection(collection, ctx, options) {
      const flow = ctx.inFlow ?? collection.flow;
      const stringify2 = flow ? stringifyFlowCollection : stringifyBlockCollection;
      return stringify2(collection, ctx, options);
    }
    function stringifyBlockCollection({ comment, items }, ctx, { blockItemPrefix, flowChars, itemIndent, onChompKeep, onComment }) {
      const { indent, options: { commentString } } = ctx;
      const itemCtx = Object.assign({}, ctx, { indent: itemIndent, type: null });
      let chompKeep = false;
      const lines = [];
      for (let i = 0; i < items.length; ++i) {
        const item = items[i];
        let comment2 = null;
        if (identity.isNode(item)) {
          if (!chompKeep && item.spaceBefore)
            lines.push("");
          addCommentBefore(ctx, lines, item.commentBefore, chompKeep);
          if (item.comment)
            comment2 = item.comment;
        } else if (identity.isPair(item)) {
          const ik = identity.isNode(item.key) ? item.key : null;
          if (ik) {
            if (!chompKeep && ik.spaceBefore)
              lines.push("");
            addCommentBefore(ctx, lines, ik.commentBefore, chompKeep);
          }
        }
        chompKeep = false;
        let str3 = stringify.stringify(item, itemCtx, () => comment2 = null, () => chompKeep = true);
        if (comment2)
          str3 += stringifyComment.lineComment(str3, itemIndent, commentString(comment2));
        if (chompKeep && comment2)
          chompKeep = false;
        lines.push(blockItemPrefix + str3);
      }
      let str2;
      if (lines.length === 0) {
        str2 = flowChars.start + flowChars.end;
      } else {
        str2 = lines[0];
        for (let i = 1; i < lines.length; ++i) {
          const line = lines[i];
          str2 += line ? `
${indent}${line}` : "\n";
        }
      }
      if (comment) {
        str2 += "\n" + stringifyComment.indentComment(commentString(comment), indent);
        if (onComment)
          onComment();
      } else if (chompKeep && onChompKeep)
        onChompKeep();
      return str2;
    }
    function stringifyFlowCollection({ items }, ctx, { flowChars, itemIndent }) {
      const { indent, indentStep, flowCollectionPadding: fcPadding, options: { commentString } } = ctx;
      itemIndent += indentStep;
      const itemCtx = Object.assign({}, ctx, {
        indent: itemIndent,
        inFlow: true,
        type: null
      });
      let reqNewline = false;
      let linesAtValue = 0;
      const lines = [];
      for (let i = 0; i < items.length; ++i) {
        const item = items[i];
        let comment = null;
        if (identity.isNode(item)) {
          if (item.spaceBefore)
            lines.push("");
          addCommentBefore(ctx, lines, item.commentBefore, false);
          if (item.comment)
            comment = item.comment;
        } else if (identity.isPair(item)) {
          const ik = identity.isNode(item.key) ? item.key : null;
          if (ik) {
            if (ik.spaceBefore)
              lines.push("");
            addCommentBefore(ctx, lines, ik.commentBefore, false);
            if (ik.comment)
              reqNewline = true;
          }
          const iv = identity.isNode(item.value) ? item.value : null;
          if (iv) {
            if (iv.comment)
              comment = iv.comment;
            if (iv.commentBefore)
              reqNewline = true;
          } else if (item.value == null && ik?.comment) {
            comment = ik.comment;
          }
        }
        if (comment)
          reqNewline = true;
        let str2 = stringify.stringify(item, itemCtx, () => comment = null);
        reqNewline || (reqNewline = lines.length > linesAtValue || str2.includes("\n"));
        if (i < items.length - 1) {
          str2 += ",";
        } else if (ctx.options.trailingComma) {
          if (ctx.options.lineWidth > 0) {
            reqNewline || (reqNewline = lines.reduce((sum, line) => sum + line.length + 2, 2) + (str2.length + 2) > ctx.options.lineWidth);
          }
          if (reqNewline) {
            str2 += ",";
          }
        }
        if (comment)
          str2 += stringifyComment.lineComment(str2, itemIndent, commentString(comment));
        lines.push(str2);
        linesAtValue = lines.length;
      }
      const { start, end } = flowChars;
      if (lines.length === 0) {
        return start + end;
      } else {
        if (!reqNewline) {
          const len = lines.reduce((sum, line) => sum + line.length + 2, 2);
          reqNewline = ctx.options.lineWidth > 0 && len > ctx.options.lineWidth;
        }
        if (reqNewline) {
          let str2 = start;
          for (const line of lines)
            str2 += line ? `
${indentStep}${indent}${line}` : "\n";
          return `${str2}
${indent}${end}`;
        } else {
          return `${start}${fcPadding}${lines.join(" ")}${fcPadding}${end}`;
        }
      }
    }
    function addCommentBefore({ indent, options: { commentString } }, lines, comment, chompKeep) {
      if (comment && chompKeep)
        comment = comment.replace(/^\n+/, "");
      if (comment) {
        const ic = stringifyComment.indentComment(commentString(comment), indent);
        lines.push(ic.trimStart());
      }
    }
    exports.stringifyCollection = stringifyCollection;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/YAMLMap.js
var require_YAMLMap = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/YAMLMap.js"(exports) {
    "use strict";
    var stringifyCollection = require_stringifyCollection();
    var addPairToJSMap = require_addPairToJSMap();
    var Collection = require_Collection();
    var identity = require_identity();
    var Pair = require_Pair();
    var Scalar = require_Scalar();
    function findPair(items, key) {
      const k = identity.isScalar(key) ? key.value : key;
      for (const it of items) {
        if (identity.isPair(it)) {
          if (it.key === key || it.key === k)
            return it;
          if (identity.isScalar(it.key) && it.key.value === k)
            return it;
        }
      }
      return void 0;
    }
    var YAMLMap = class extends Collection.Collection {
      static get tagName() {
        return "tag:yaml.org,2002:map";
      }
      constructor(schema) {
        super(identity.MAP, schema);
        this.items = [];
      }
      /**
       * A generic collection parsing method that can be extended
       * to other node classes that inherit from YAMLMap
       */
      static from(schema, obj, ctx) {
        const { keepUndefined, replacer } = ctx;
        const map = new this(schema);
        const add = (key, value) => {
          if (typeof replacer === "function")
            value = replacer.call(obj, key, value);
          else if (Array.isArray(replacer) && !replacer.includes(key))
            return;
          if (value !== void 0 || keepUndefined)
            map.items.push(Pair.createPair(key, value, ctx));
        };
        if (obj instanceof Map) {
          for (const [key, value] of obj)
            add(key, value);
        } else if (obj && typeof obj === "object") {
          for (const key of Object.keys(obj))
            add(key, obj[key]);
        }
        if (typeof schema.sortMapEntries === "function") {
          map.items.sort(schema.sortMapEntries);
        }
        return map;
      }
      /**
       * Adds a value to the collection.
       *
       * @param overwrite - If not set `true`, using a key that is already in the
       *   collection will throw. Otherwise, overwrites the previous value.
       */
      add(pair, overwrite) {
        let _pair;
        if (identity.isPair(pair))
          _pair = pair;
        else if (!pair || typeof pair !== "object" || !("key" in pair)) {
          _pair = new Pair.Pair(pair, pair?.value);
        } else
          _pair = new Pair.Pair(pair.key, pair.value);
        const prev = findPair(this.items, _pair.key);
        const sortEntries = this.schema?.sortMapEntries;
        if (prev) {
          if (!overwrite)
            throw new Error(`Key ${_pair.key} already set`);
          if (identity.isScalar(prev.value) && Scalar.isScalarValue(_pair.value))
            prev.value.value = _pair.value;
          else
            prev.value = _pair.value;
        } else if (sortEntries) {
          const i = this.items.findIndex((item) => sortEntries(_pair, item) < 0);
          if (i === -1)
            this.items.push(_pair);
          else
            this.items.splice(i, 0, _pair);
        } else {
          this.items.push(_pair);
        }
      }
      delete(key) {
        const it = findPair(this.items, key);
        if (!it)
          return false;
        const del = this.items.splice(this.items.indexOf(it), 1);
        return del.length > 0;
      }
      get(key, keepScalar) {
        const it = findPair(this.items, key);
        const node = it?.value;
        return (!keepScalar && identity.isScalar(node) ? node.value : node) ?? void 0;
      }
      has(key) {
        return !!findPair(this.items, key);
      }
      set(key, value) {
        this.add(new Pair.Pair(key, value), true);
      }
      /**
       * @param ctx - Conversion context, originally set in Document#toJS()
       * @param {Class} Type - If set, forces the returned collection type
       * @returns Instance of Type, Map, or Object
       */
      toJSON(_, ctx, Type) {
        const map = Type ? new Type() : ctx?.mapAsMap ? /* @__PURE__ */ new Map() : {};
        if (ctx?.onCreate)
          ctx.onCreate(map);
        for (const item of this.items)
          addPairToJSMap.addPairToJSMap(ctx, map, item);
        return map;
      }
      toString(ctx, onComment, onChompKeep) {
        if (!ctx)
          return JSON.stringify(this);
        for (const item of this.items) {
          if (!identity.isPair(item))
            throw new Error(`Map items must all be pairs; found ${JSON.stringify(item)} instead`);
        }
        if (!ctx.allNullValues && this.hasAllNullValues(false))
          ctx = Object.assign({}, ctx, { allNullValues: true });
        return stringifyCollection.stringifyCollection(this, ctx, {
          blockItemPrefix: "",
          flowChars: { start: "{", end: "}" },
          itemIndent: ctx.indent || "",
          onChompKeep,
          onComment
        });
      }
    };
    exports.YAMLMap = YAMLMap;
    exports.findPair = findPair;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/common/map.js
var require_map = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/common/map.js"(exports) {
    "use strict";
    var identity = require_identity();
    var YAMLMap = require_YAMLMap();
    var map = {
      collection: "map",
      default: true,
      nodeClass: YAMLMap.YAMLMap,
      tag: "tag:yaml.org,2002:map",
      resolve(map2, onError) {
        if (!identity.isMap(map2))
          onError("Expected a mapping for this tag");
        return map2;
      },
      createNode: (schema, obj, ctx) => YAMLMap.YAMLMap.from(schema, obj, ctx)
    };
    exports.map = map;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/YAMLSeq.js
var require_YAMLSeq = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/nodes/YAMLSeq.js"(exports) {
    "use strict";
    var createNode = require_createNode();
    var stringifyCollection = require_stringifyCollection();
    var Collection = require_Collection();
    var identity = require_identity();
    var Scalar = require_Scalar();
    var toJS = require_toJS();
    var YAMLSeq = class extends Collection.Collection {
      static get tagName() {
        return "tag:yaml.org,2002:seq";
      }
      constructor(schema) {
        super(identity.SEQ, schema);
        this.items = [];
      }
      add(value) {
        this.items.push(value);
      }
      /**
       * Removes a value from the collection.
       *
       * `key` must contain a representation of an integer for this to succeed.
       * It may be wrapped in a `Scalar`.
       *
       * @returns `true` if the item was found and removed.
       */
      delete(key) {
        const idx = asItemIndex(key);
        if (typeof idx !== "number")
          return false;
        const del = this.items.splice(idx, 1);
        return del.length > 0;
      }
      get(key, keepScalar) {
        const idx = asItemIndex(key);
        if (typeof idx !== "number")
          return void 0;
        const it = this.items[idx];
        return !keepScalar && identity.isScalar(it) ? it.value : it;
      }
      /**
       * Checks if the collection includes a value with the key `key`.
       *
       * `key` must contain a representation of an integer for this to succeed.
       * It may be wrapped in a `Scalar`.
       */
      has(key) {
        const idx = asItemIndex(key);
        return typeof idx === "number" && idx < this.items.length;
      }
      /**
       * Sets a value in this collection. For `!!set`, `value` needs to be a
       * boolean to add/remove the item from the set.
       *
       * If `key` does not contain a representation of an integer, this will throw.
       * It may be wrapped in a `Scalar`.
       */
      set(key, value) {
        const idx = asItemIndex(key);
        if (typeof idx !== "number")
          throw new Error(`Expected a valid index, not ${key}.`);
        const prev = this.items[idx];
        if (identity.isScalar(prev) && Scalar.isScalarValue(value))
          prev.value = value;
        else
          this.items[idx] = value;
      }
      toJSON(_, ctx) {
        const seq = [];
        if (ctx?.onCreate)
          ctx.onCreate(seq);
        let i = 0;
        for (const item of this.items)
          seq.push(toJS.toJS(item, String(i++), ctx));
        return seq;
      }
      toString(ctx, onComment, onChompKeep) {
        if (!ctx)
          return JSON.stringify(this);
        return stringifyCollection.stringifyCollection(this, ctx, {
          blockItemPrefix: "- ",
          flowChars: { start: "[", end: "]" },
          itemIndent: (ctx.indent || "") + "  ",
          onChompKeep,
          onComment
        });
      }
      static from(schema, obj, ctx) {
        const { replacer } = ctx;
        const seq = new this(schema);
        if (obj && Symbol.iterator in Object(obj)) {
          let i = 0;
          for (let it of obj) {
            if (typeof replacer === "function") {
              const key = obj instanceof Set ? it : String(i++);
              it = replacer.call(obj, key, it);
            }
            seq.items.push(createNode.createNode(it, void 0, ctx));
          }
        }
        return seq;
      }
    };
    function asItemIndex(key) {
      let idx = identity.isScalar(key) ? key.value : key;
      if (idx && typeof idx === "string")
        idx = Number(idx);
      return typeof idx === "number" && Number.isInteger(idx) && idx >= 0 ? idx : null;
    }
    exports.YAMLSeq = YAMLSeq;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/common/seq.js
var require_seq = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/common/seq.js"(exports) {
    "use strict";
    var identity = require_identity();
    var YAMLSeq = require_YAMLSeq();
    var seq = {
      collection: "seq",
      default: true,
      nodeClass: YAMLSeq.YAMLSeq,
      tag: "tag:yaml.org,2002:seq",
      resolve(seq2, onError) {
        if (!identity.isSeq(seq2))
          onError("Expected a sequence for this tag");
        return seq2;
      },
      createNode: (schema, obj, ctx) => YAMLSeq.YAMLSeq.from(schema, obj, ctx)
    };
    exports.seq = seq;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/common/string.js
var require_string = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/common/string.js"(exports) {
    "use strict";
    var stringifyString = require_stringifyString();
    var string = {
      identify: (value) => typeof value === "string",
      default: true,
      tag: "tag:yaml.org,2002:str",
      resolve: (str2) => str2,
      stringify(item, ctx, onComment, onChompKeep) {
        ctx = Object.assign({ actualString: true }, ctx);
        return stringifyString.stringifyString(item, ctx, onComment, onChompKeep);
      }
    };
    exports.string = string;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/common/null.js
var require_null = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/common/null.js"(exports) {
    "use strict";
    var Scalar = require_Scalar();
    var nullTag = {
      identify: (value) => value == null,
      createNode: () => new Scalar.Scalar(null),
      default: true,
      tag: "tag:yaml.org,2002:null",
      test: /^(?:~|[Nn]ull|NULL)?$/,
      resolve: () => new Scalar.Scalar(null),
      stringify: ({ source }, ctx) => typeof source === "string" && nullTag.test.test(source) ? source : ctx.options.nullStr
    };
    exports.nullTag = nullTag;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/core/bool.js
var require_bool = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/core/bool.js"(exports) {
    "use strict";
    var Scalar = require_Scalar();
    var boolTag = {
      identify: (value) => typeof value === "boolean",
      default: true,
      tag: "tag:yaml.org,2002:bool",
      test: /^(?:[Tt]rue|TRUE|[Ff]alse|FALSE)$/,
      resolve: (str2) => new Scalar.Scalar(str2[0] === "t" || str2[0] === "T"),
      stringify({ source, value }, ctx) {
        if (source && boolTag.test.test(source)) {
          const sv = source[0] === "t" || source[0] === "T";
          if (value === sv)
            return source;
        }
        return value ? ctx.options.trueStr : ctx.options.falseStr;
      }
    };
    exports.boolTag = boolTag;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyNumber.js
var require_stringifyNumber = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyNumber.js"(exports) {
    "use strict";
    function stringifyNumber({ format, minFractionDigits, tag, value }) {
      if (typeof value === "bigint")
        return String(value);
      const num = typeof value === "number" ? value : Number(value);
      if (!isFinite(num))
        return isNaN(num) ? ".nan" : num < 0 ? "-.inf" : ".inf";
      let n = Object.is(value, -0) ? "-0" : JSON.stringify(value);
      if (!format && minFractionDigits && (!tag || tag === "tag:yaml.org,2002:float") && /^-?\d/.test(n) && !n.includes("e")) {
        let i = n.indexOf(".");
        if (i < 0) {
          i = n.length;
          n += ".";
        }
        let d = minFractionDigits - (n.length - i - 1);
        while (d-- > 0)
          n += "0";
      }
      return n;
    }
    exports.stringifyNumber = stringifyNumber;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/core/float.js
var require_float = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/core/float.js"(exports) {
    "use strict";
    var Scalar = require_Scalar();
    var stringifyNumber = require_stringifyNumber();
    var floatNaN = {
      identify: (value) => typeof value === "number",
      default: true,
      tag: "tag:yaml.org,2002:float",
      test: /^(?:[-+]?\.(?:inf|Inf|INF)|\.nan|\.NaN|\.NAN)$/,
      resolve: (str2) => str2.slice(-3).toLowerCase() === "nan" ? NaN : str2[0] === "-" ? Number.NEGATIVE_INFINITY : Number.POSITIVE_INFINITY,
      stringify: stringifyNumber.stringifyNumber
    };
    var floatExp = {
      identify: (value) => typeof value === "number",
      default: true,
      tag: "tag:yaml.org,2002:float",
      format: "EXP",
      test: /^[-+]?(?:\.[0-9]+|[0-9]+(?:\.[0-9]*)?)[eE][-+]?[0-9]+$/,
      resolve: (str2) => parseFloat(str2),
      stringify(node) {
        const num = Number(node.value);
        return isFinite(num) ? num.toExponential() : stringifyNumber.stringifyNumber(node);
      }
    };
    var float = {
      identify: (value) => typeof value === "number",
      default: true,
      tag: "tag:yaml.org,2002:float",
      test: /^[-+]?(?:\.[0-9]+|[0-9]+\.[0-9]*)$/,
      resolve(str2) {
        const node = new Scalar.Scalar(parseFloat(str2));
        const dot = str2.indexOf(".");
        if (dot !== -1 && str2[str2.length - 1] === "0")
          node.minFractionDigits = str2.length - dot - 1;
        return node;
      },
      stringify: stringifyNumber.stringifyNumber
    };
    exports.float = float;
    exports.floatExp = floatExp;
    exports.floatNaN = floatNaN;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/core/int.js
var require_int = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/core/int.js"(exports) {
    "use strict";
    var stringifyNumber = require_stringifyNumber();
    var intIdentify = (value) => typeof value === "bigint" || Number.isInteger(value);
    var intResolve = (str2, offset, radix, { intAsBigInt }) => intAsBigInt ? BigInt(str2) : parseInt(str2.substring(offset), radix);
    function intStringify(node, radix, prefix) {
      const { value } = node;
      if (intIdentify(value) && value >= 0)
        return prefix + value.toString(radix);
      return stringifyNumber.stringifyNumber(node);
    }
    var intOct = {
      identify: (value) => intIdentify(value) && value >= 0,
      default: true,
      tag: "tag:yaml.org,2002:int",
      format: "OCT",
      test: /^0o[0-7]+$/,
      resolve: (str2, _onError, opt) => intResolve(str2, 2, 8, opt),
      stringify: (node) => intStringify(node, 8, "0o")
    };
    var int = {
      identify: intIdentify,
      default: true,
      tag: "tag:yaml.org,2002:int",
      test: /^[-+]?[0-9]+$/,
      resolve: (str2, _onError, opt) => intResolve(str2, 0, 10, opt),
      stringify: stringifyNumber.stringifyNumber
    };
    var intHex = {
      identify: (value) => intIdentify(value) && value >= 0,
      default: true,
      tag: "tag:yaml.org,2002:int",
      format: "HEX",
      test: /^0x[0-9a-fA-F]+$/,
      resolve: (str2, _onError, opt) => intResolve(str2, 2, 16, opt),
      stringify: (node) => intStringify(node, 16, "0x")
    };
    exports.int = int;
    exports.intHex = intHex;
    exports.intOct = intOct;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/core/schema.js
var require_schema = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/core/schema.js"(exports) {
    "use strict";
    var map = require_map();
    var _null = require_null();
    var seq = require_seq();
    var string = require_string();
    var bool = require_bool();
    var float = require_float();
    var int = require_int();
    var schema = [
      map.map,
      seq.seq,
      string.string,
      _null.nullTag,
      bool.boolTag,
      int.intOct,
      int.int,
      int.intHex,
      float.floatNaN,
      float.floatExp,
      float.float
    ];
    exports.schema = schema;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/json/schema.js
var require_schema2 = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/json/schema.js"(exports) {
    "use strict";
    var Scalar = require_Scalar();
    var map = require_map();
    var seq = require_seq();
    function intIdentify(value) {
      return typeof value === "bigint" || Number.isInteger(value);
    }
    var stringifyJSON = ({ value }) => JSON.stringify(value);
    var jsonScalars = [
      {
        identify: (value) => typeof value === "string",
        default: true,
        tag: "tag:yaml.org,2002:str",
        resolve: (str2) => str2,
        stringify: stringifyJSON
      },
      {
        identify: (value) => value == null,
        createNode: () => new Scalar.Scalar(null),
        default: true,
        tag: "tag:yaml.org,2002:null",
        test: /^null$/,
        resolve: () => null,
        stringify: stringifyJSON
      },
      {
        identify: (value) => typeof value === "boolean",
        default: true,
        tag: "tag:yaml.org,2002:bool",
        test: /^true$|^false$/,
        resolve: (str2) => str2 === "true",
        stringify: stringifyJSON
      },
      {
        identify: intIdentify,
        default: true,
        tag: "tag:yaml.org,2002:int",
        test: /^-?(?:0|[1-9][0-9]*)$/,
        resolve: (str2, _onError, { intAsBigInt }) => intAsBigInt ? BigInt(str2) : parseInt(str2, 10),
        stringify: ({ value }) => intIdentify(value) ? value.toString() : JSON.stringify(value)
      },
      {
        identify: (value) => typeof value === "number",
        default: true,
        tag: "tag:yaml.org,2002:float",
        test: /^-?(?:0|[1-9][0-9]*)(?:\.[0-9]*)?(?:[eE][-+]?[0-9]+)?$/,
        resolve: (str2) => parseFloat(str2),
        stringify: stringifyJSON
      }
    ];
    var jsonError = {
      default: true,
      tag: "",
      test: /^/,
      resolve(str2, onError) {
        onError(`Unresolved plain scalar ${JSON.stringify(str2)}`);
        return str2;
      }
    };
    var schema = [map.map, seq.seq].concat(jsonScalars, jsonError);
    exports.schema = schema;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/binary.js
var require_binary = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/binary.js"(exports) {
    "use strict";
    var node_buffer = __require("buffer");
    var Scalar = require_Scalar();
    var stringifyString = require_stringifyString();
    var binary = {
      identify: (value) => value instanceof Uint8Array,
      // Buffer inherits from Uint8Array
      default: false,
      tag: "tag:yaml.org,2002:binary",
      /**
       * Returns a Buffer in node and an Uint8Array in browsers
       *
       * To use the resulting buffer as an image, you'll want to do something like:
       *
       *   const blob = new Blob([buffer], { type: 'image/jpeg' })
       *   document.querySelector('#photo').src = URL.createObjectURL(blob)
       */
      resolve(src, onError) {
        if (typeof node_buffer.Buffer === "function") {
          return node_buffer.Buffer.from(src, "base64");
        } else if (typeof atob === "function") {
          const str2 = atob(src.replace(/[\n\r]/g, ""));
          const buffer = new Uint8Array(str2.length);
          for (let i = 0; i < str2.length; ++i)
            buffer[i] = str2.charCodeAt(i);
          return buffer;
        } else {
          onError("This environment does not support reading binary tags; either Buffer or atob is required");
          return src;
        }
      },
      stringify({ comment, type, value }, ctx, onComment, onChompKeep) {
        if (!value)
          return "";
        const buf = value;
        let str2;
        if (typeof node_buffer.Buffer === "function") {
          str2 = buf instanceof node_buffer.Buffer ? buf.toString("base64") : node_buffer.Buffer.from(buf.buffer).toString("base64");
        } else if (typeof btoa === "function") {
          let s = "";
          for (let i = 0; i < buf.length; ++i)
            s += String.fromCharCode(buf[i]);
          str2 = btoa(s);
        } else {
          throw new Error("This environment does not support writing binary tags; either Buffer or btoa is required");
        }
        type ?? (type = Scalar.Scalar.BLOCK_LITERAL);
        if (type !== Scalar.Scalar.QUOTE_DOUBLE) {
          const lineWidth = Math.max(ctx.options.lineWidth - ctx.indent.length, ctx.options.minContentWidth);
          const n = Math.ceil(str2.length / lineWidth);
          const lines = new Array(n);
          for (let i = 0, o = 0; i < n; ++i, o += lineWidth) {
            lines[i] = str2.substr(o, lineWidth);
          }
          str2 = lines.join(type === Scalar.Scalar.BLOCK_LITERAL ? "\n" : " ");
        }
        return stringifyString.stringifyString({ comment, type, value: str2 }, ctx, onComment, onChompKeep);
      }
    };
    exports.binary = binary;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/pairs.js
var require_pairs = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/pairs.js"(exports) {
    "use strict";
    var identity = require_identity();
    var Pair = require_Pair();
    var Scalar = require_Scalar();
    var YAMLSeq = require_YAMLSeq();
    function resolvePairs(seq, onError) {
      if (identity.isSeq(seq)) {
        for (let i = 0; i < seq.items.length; ++i) {
          let item = seq.items[i];
          if (identity.isPair(item))
            continue;
          else if (identity.isMap(item)) {
            if (item.items.length > 1)
              onError("Each pair must have its own sequence indicator");
            const pair = item.items[0] || new Pair.Pair(new Scalar.Scalar(null));
            if (item.commentBefore)
              pair.key.commentBefore = pair.key.commentBefore ? `${item.commentBefore}
${pair.key.commentBefore}` : item.commentBefore;
            if (item.comment) {
              const cn = pair.value ?? pair.key;
              cn.comment = cn.comment ? `${item.comment}
${cn.comment}` : item.comment;
            }
            item = pair;
          }
          seq.items[i] = identity.isPair(item) ? item : new Pair.Pair(item);
        }
      } else
        onError("Expected a sequence for this tag");
      return seq;
    }
    function createPairs(schema, iterable, ctx) {
      const { replacer } = ctx;
      const pairs2 = new YAMLSeq.YAMLSeq(schema);
      pairs2.tag = "tag:yaml.org,2002:pairs";
      let i = 0;
      if (iterable && Symbol.iterator in Object(iterable))
        for (let it of iterable) {
          if (typeof replacer === "function")
            it = replacer.call(iterable, String(i++), it);
          let key, value;
          if (Array.isArray(it)) {
            if (it.length === 2) {
              key = it[0];
              value = it[1];
            } else
              throw new TypeError(`Expected [key, value] tuple: ${it}`);
          } else if (it && it instanceof Object) {
            const keys = Object.keys(it);
            if (keys.length === 1) {
              key = keys[0];
              value = it[key];
            } else {
              throw new TypeError(`Expected tuple with one key, not ${keys.length} keys`);
            }
          } else {
            key = it;
          }
          pairs2.items.push(Pair.createPair(key, value, ctx));
        }
      return pairs2;
    }
    var pairs = {
      collection: "seq",
      default: false,
      tag: "tag:yaml.org,2002:pairs",
      resolve: resolvePairs,
      createNode: createPairs
    };
    exports.createPairs = createPairs;
    exports.pairs = pairs;
    exports.resolvePairs = resolvePairs;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/omap.js
var require_omap = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/omap.js"(exports) {
    "use strict";
    var identity = require_identity();
    var toJS = require_toJS();
    var YAMLMap = require_YAMLMap();
    var YAMLSeq = require_YAMLSeq();
    var pairs = require_pairs();
    var YAMLOMap = class _YAMLOMap extends YAMLSeq.YAMLSeq {
      constructor() {
        super();
        this.add = YAMLMap.YAMLMap.prototype.add.bind(this);
        this.delete = YAMLMap.YAMLMap.prototype.delete.bind(this);
        this.get = YAMLMap.YAMLMap.prototype.get.bind(this);
        this.has = YAMLMap.YAMLMap.prototype.has.bind(this);
        this.set = YAMLMap.YAMLMap.prototype.set.bind(this);
        this.tag = _YAMLOMap.tag;
      }
      /**
       * If `ctx` is given, the return type is actually `Map<unknown, unknown>`,
       * but TypeScript won't allow widening the signature of a child method.
       */
      toJSON(_, ctx) {
        if (!ctx)
          return super.toJSON(_);
        const map = /* @__PURE__ */ new Map();
        if (ctx?.onCreate)
          ctx.onCreate(map);
        for (const pair of this.items) {
          let key, value;
          if (identity.isPair(pair)) {
            key = toJS.toJS(pair.key, "", ctx);
            value = toJS.toJS(pair.value, key, ctx);
          } else {
            key = toJS.toJS(pair, "", ctx);
          }
          if (map.has(key))
            throw new Error("Ordered maps must not include duplicate keys");
          map.set(key, value);
        }
        return map;
      }
      static from(schema, iterable, ctx) {
        const pairs$1 = pairs.createPairs(schema, iterable, ctx);
        const omap2 = new this();
        omap2.items = pairs$1.items;
        return omap2;
      }
    };
    YAMLOMap.tag = "tag:yaml.org,2002:omap";
    var omap = {
      collection: "seq",
      identify: (value) => value instanceof Map,
      nodeClass: YAMLOMap,
      default: false,
      tag: "tag:yaml.org,2002:omap",
      resolve(seq, onError) {
        const pairs$1 = pairs.resolvePairs(seq, onError);
        const seenKeys = [];
        for (const { key } of pairs$1.items) {
          if (identity.isScalar(key)) {
            if (seenKeys.includes(key.value)) {
              onError(`Ordered maps must not include duplicate keys: ${key.value}`);
            } else {
              seenKeys.push(key.value);
            }
          }
        }
        return Object.assign(new YAMLOMap(), pairs$1);
      },
      createNode: (schema, iterable, ctx) => YAMLOMap.from(schema, iterable, ctx)
    };
    exports.YAMLOMap = YAMLOMap;
    exports.omap = omap;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/bool.js
var require_bool2 = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/bool.js"(exports) {
    "use strict";
    var Scalar = require_Scalar();
    function boolStringify({ value, source }, ctx) {
      const boolObj = value ? trueTag : falseTag;
      if (source && boolObj.test.test(source))
        return source;
      return value ? ctx.options.trueStr : ctx.options.falseStr;
    }
    var trueTag = {
      identify: (value) => value === true,
      default: true,
      tag: "tag:yaml.org,2002:bool",
      test: /^(?:Y|y|[Yy]es|YES|[Tt]rue|TRUE|[Oo]n|ON)$/,
      resolve: () => new Scalar.Scalar(true),
      stringify: boolStringify
    };
    var falseTag = {
      identify: (value) => value === false,
      default: true,
      tag: "tag:yaml.org,2002:bool",
      test: /^(?:N|n|[Nn]o|NO|[Ff]alse|FALSE|[Oo]ff|OFF)$/,
      resolve: () => new Scalar.Scalar(false),
      stringify: boolStringify
    };
    exports.falseTag = falseTag;
    exports.trueTag = trueTag;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/float.js
var require_float2 = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/float.js"(exports) {
    "use strict";
    var Scalar = require_Scalar();
    var stringifyNumber = require_stringifyNumber();
    var floatNaN = {
      identify: (value) => typeof value === "number",
      default: true,
      tag: "tag:yaml.org,2002:float",
      test: /^(?:[-+]?\.(?:inf|Inf|INF)|\.nan|\.NaN|\.NAN)$/,
      resolve: (str2) => str2.slice(-3).toLowerCase() === "nan" ? NaN : str2[0] === "-" ? Number.NEGATIVE_INFINITY : Number.POSITIVE_INFINITY,
      stringify: stringifyNumber.stringifyNumber
    };
    var floatExp = {
      identify: (value) => typeof value === "number",
      default: true,
      tag: "tag:yaml.org,2002:float",
      format: "EXP",
      test: /^[-+]?(?:[0-9][0-9_]*)?(?:\.[0-9_]*)?[eE][-+]?[0-9]+$/,
      resolve: (str2) => parseFloat(str2.replace(/_/g, "")),
      stringify(node) {
        const num = Number(node.value);
        return isFinite(num) ? num.toExponential() : stringifyNumber.stringifyNumber(node);
      }
    };
    var float = {
      identify: (value) => typeof value === "number",
      default: true,
      tag: "tag:yaml.org,2002:float",
      test: /^[-+]?(?:[0-9][0-9_]*)?\.[0-9_]*$/,
      resolve(str2) {
        const node = new Scalar.Scalar(parseFloat(str2.replace(/_/g, "")));
        const dot = str2.indexOf(".");
        if (dot !== -1) {
          const f = str2.substring(dot + 1).replace(/_/g, "");
          if (f[f.length - 1] === "0")
            node.minFractionDigits = f.length;
        }
        return node;
      },
      stringify: stringifyNumber.stringifyNumber
    };
    exports.float = float;
    exports.floatExp = floatExp;
    exports.floatNaN = floatNaN;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/int.js
var require_int2 = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/int.js"(exports) {
    "use strict";
    var stringifyNumber = require_stringifyNumber();
    var intIdentify = (value) => typeof value === "bigint" || Number.isInteger(value);
    function intResolve(str2, offset, radix, { intAsBigInt }) {
      const sign = str2[0];
      if (sign === "-" || sign === "+")
        offset += 1;
      str2 = str2.substring(offset).replace(/_/g, "");
      if (intAsBigInt) {
        switch (radix) {
          case 2:
            str2 = `0b${str2}`;
            break;
          case 8:
            str2 = `0o${str2}`;
            break;
          case 16:
            str2 = `0x${str2}`;
            break;
        }
        const n2 = BigInt(str2);
        return sign === "-" ? BigInt(-1) * n2 : n2;
      }
      const n = parseInt(str2, radix);
      return sign === "-" ? -1 * n : n;
    }
    function intStringify(node, radix, prefix) {
      const { value } = node;
      if (intIdentify(value)) {
        const str2 = value.toString(radix);
        return value < 0 ? "-" + prefix + str2.substr(1) : prefix + str2;
      }
      return stringifyNumber.stringifyNumber(node);
    }
    var intBin = {
      identify: intIdentify,
      default: true,
      tag: "tag:yaml.org,2002:int",
      format: "BIN",
      test: /^[-+]?0b[0-1_]+$/,
      resolve: (str2, _onError, opt) => intResolve(str2, 2, 2, opt),
      stringify: (node) => intStringify(node, 2, "0b")
    };
    var intOct = {
      identify: intIdentify,
      default: true,
      tag: "tag:yaml.org,2002:int",
      format: "OCT",
      test: /^[-+]?0[0-7_]+$/,
      resolve: (str2, _onError, opt) => intResolve(str2, 1, 8, opt),
      stringify: (node) => intStringify(node, 8, "0")
    };
    var int = {
      identify: intIdentify,
      default: true,
      tag: "tag:yaml.org,2002:int",
      test: /^[-+]?[0-9][0-9_]*$/,
      resolve: (str2, _onError, opt) => intResolve(str2, 0, 10, opt),
      stringify: stringifyNumber.stringifyNumber
    };
    var intHex = {
      identify: intIdentify,
      default: true,
      tag: "tag:yaml.org,2002:int",
      format: "HEX",
      test: /^[-+]?0x[0-9a-fA-F_]+$/,
      resolve: (str2, _onError, opt) => intResolve(str2, 2, 16, opt),
      stringify: (node) => intStringify(node, 16, "0x")
    };
    exports.int = int;
    exports.intBin = intBin;
    exports.intHex = intHex;
    exports.intOct = intOct;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/set.js
var require_set = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/set.js"(exports) {
    "use strict";
    var identity = require_identity();
    var Pair = require_Pair();
    var YAMLMap = require_YAMLMap();
    var YAMLSet = class _YAMLSet extends YAMLMap.YAMLMap {
      constructor(schema) {
        super(schema);
        this.tag = _YAMLSet.tag;
      }
      add(key) {
        let pair;
        if (identity.isPair(key))
          pair = key;
        else if (key && typeof key === "object" && "key" in key && "value" in key && key.value === null)
          pair = new Pair.Pair(key.key, null);
        else
          pair = new Pair.Pair(key, null);
        const prev = YAMLMap.findPair(this.items, pair.key);
        if (!prev)
          this.items.push(pair);
      }
      /**
       * If `keepPair` is `true`, returns the Pair matching `key`.
       * Otherwise, returns the value of that Pair's key.
       */
      get(key, keepPair) {
        const pair = YAMLMap.findPair(this.items, key);
        return !keepPair && identity.isPair(pair) ? identity.isScalar(pair.key) ? pair.key.value : pair.key : pair;
      }
      set(key, value) {
        if (typeof value !== "boolean")
          throw new Error(`Expected boolean value for set(key, value) in a YAML set, not ${typeof value}`);
        const prev = YAMLMap.findPair(this.items, key);
        if (prev && !value) {
          this.items.splice(this.items.indexOf(prev), 1);
        } else if (!prev && value) {
          this.items.push(new Pair.Pair(key));
        }
      }
      toJSON(_, ctx) {
        return super.toJSON(_, ctx, Set);
      }
      toString(ctx, onComment, onChompKeep) {
        if (!ctx)
          return JSON.stringify(this);
        if (this.hasAllNullValues(true))
          return super.toString(Object.assign({}, ctx, { allNullValues: true }), onComment, onChompKeep);
        else
          throw new Error("Set items must all have null values");
      }
      static from(schema, iterable, ctx) {
        const { replacer } = ctx;
        const set2 = new this(schema);
        if (iterable && Symbol.iterator in Object(iterable))
          for (let value of iterable) {
            if (typeof replacer === "function")
              value = replacer.call(iterable, value, value);
            set2.items.push(Pair.createPair(value, null, ctx));
          }
        return set2;
      }
    };
    YAMLSet.tag = "tag:yaml.org,2002:set";
    var set = {
      collection: "map",
      identify: (value) => value instanceof Set,
      nodeClass: YAMLSet,
      default: false,
      tag: "tag:yaml.org,2002:set",
      createNode: (schema, iterable, ctx) => YAMLSet.from(schema, iterable, ctx),
      resolve(map, onError) {
        if (identity.isMap(map)) {
          if (map.hasAllNullValues(true))
            return Object.assign(new YAMLSet(), map);
          else
            onError("Set items must all have null values");
        } else
          onError("Expected a mapping for this tag");
        return map;
      }
    };
    exports.YAMLSet = YAMLSet;
    exports.set = set;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/timestamp.js
var require_timestamp = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/timestamp.js"(exports) {
    "use strict";
    var stringifyNumber = require_stringifyNumber();
    function parseSexagesimal(str2, asBigInt) {
      const sign = str2[0];
      const parts = sign === "-" || sign === "+" ? str2.substring(1) : str2;
      const num = (n) => asBigInt ? BigInt(n) : Number(n);
      const res = parts.replace(/_/g, "").split(":").reduce((res2, p) => res2 * num(60) + num(p), num(0));
      return sign === "-" ? num(-1) * res : res;
    }
    function stringifySexagesimal(node) {
      let { value } = node;
      let num = (n) => n;
      if (typeof value === "bigint")
        num = (n) => BigInt(n);
      else if (isNaN(value) || !isFinite(value))
        return stringifyNumber.stringifyNumber(node);
      let sign = "";
      if (value < 0) {
        sign = "-";
        value *= num(-1);
      }
      const _60 = num(60);
      const parts = [value % _60];
      if (value < 60) {
        parts.unshift(0);
      } else {
        value = (value - parts[0]) / _60;
        parts.unshift(value % _60);
        if (value >= 60) {
          value = (value - parts[0]) / _60;
          parts.unshift(value);
        }
      }
      return sign + parts.map((n) => String(n).padStart(2, "0")).join(":").replace(/000000\d*$/, "");
    }
    var intTime = {
      identify: (value) => typeof value === "bigint" || Number.isInteger(value),
      default: true,
      tag: "tag:yaml.org,2002:int",
      format: "TIME",
      test: /^[-+]?[0-9][0-9_]*(?::[0-5]?[0-9])+$/,
      resolve: (str2, _onError, { intAsBigInt }) => parseSexagesimal(str2, intAsBigInt),
      stringify: stringifySexagesimal
    };
    var floatTime = {
      identify: (value) => typeof value === "number",
      default: true,
      tag: "tag:yaml.org,2002:float",
      format: "TIME",
      test: /^[-+]?[0-9][0-9_]*(?::[0-5]?[0-9])+\.[0-9_]*$/,
      resolve: (str2) => parseSexagesimal(str2, false),
      stringify: stringifySexagesimal
    };
    var timestamp2 = {
      identify: (value) => value instanceof Date,
      default: true,
      tag: "tag:yaml.org,2002:timestamp",
      // If the time zone is omitted, the timestamp is assumed to be specified in UTC. The time part
      // may be omitted altogether, resulting in a date format. In such a case, the time part is
      // assumed to be 00:00:00Z (start of day, UTC).
      test: RegExp("^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})(?:(?:t|T|[ \\t]+)([0-9]{1,2}):([0-9]{1,2}):([0-9]{1,2}(\\.[0-9]+)?)(?:[ \\t]*(Z|[-+][012]?[0-9](?::[0-9]{2})?))?)?$"),
      resolve(str2) {
        const match = str2.match(timestamp2.test);
        if (!match)
          throw new Error("!!timestamp expects a date, starting with yyyy-mm-dd");
        const [, year, month, day, hour, minute, second] = match.map(Number);
        const millisec = match[7] ? Number((match[7] + "00").substr(1, 3)) : 0;
        let date = Date.UTC(year, month - 1, day, hour || 0, minute || 0, second || 0, millisec);
        const tz = match[8];
        if (tz && tz !== "Z") {
          let d = parseSexagesimal(tz, false);
          if (Math.abs(d) < 30)
            d *= 60;
          date -= 6e4 * d;
        }
        return new Date(date);
      },
      stringify: ({ value }) => value?.toISOString().replace(/(T00:00:00)?\.000Z$/, "") ?? ""
    };
    exports.floatTime = floatTime;
    exports.intTime = intTime;
    exports.timestamp = timestamp2;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/schema.js
var require_schema3 = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/yaml-1.1/schema.js"(exports) {
    "use strict";
    var map = require_map();
    var _null = require_null();
    var seq = require_seq();
    var string = require_string();
    var binary = require_binary();
    var bool = require_bool2();
    var float = require_float2();
    var int = require_int2();
    var merge = require_merge();
    var omap = require_omap();
    var pairs = require_pairs();
    var set = require_set();
    var timestamp2 = require_timestamp();
    var schema = [
      map.map,
      seq.seq,
      string.string,
      _null.nullTag,
      bool.trueTag,
      bool.falseTag,
      int.intBin,
      int.intOct,
      int.int,
      int.intHex,
      float.floatNaN,
      float.floatExp,
      float.float,
      binary.binary,
      merge.merge,
      omap.omap,
      pairs.pairs,
      set.set,
      timestamp2.intTime,
      timestamp2.floatTime,
      timestamp2.timestamp
    ];
    exports.schema = schema;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/tags.js
var require_tags = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/tags.js"(exports) {
    "use strict";
    var map = require_map();
    var _null = require_null();
    var seq = require_seq();
    var string = require_string();
    var bool = require_bool();
    var float = require_float();
    var int = require_int();
    var schema = require_schema();
    var schema$1 = require_schema2();
    var binary = require_binary();
    var merge = require_merge();
    var omap = require_omap();
    var pairs = require_pairs();
    var schema$2 = require_schema3();
    var set = require_set();
    var timestamp2 = require_timestamp();
    var schemas = /* @__PURE__ */ new Map([
      ["core", schema.schema],
      ["failsafe", [map.map, seq.seq, string.string]],
      ["json", schema$1.schema],
      ["yaml11", schema$2.schema],
      ["yaml-1.1", schema$2.schema]
    ]);
    var tagsByName = {
      binary: binary.binary,
      bool: bool.boolTag,
      float: float.float,
      floatExp: float.floatExp,
      floatNaN: float.floatNaN,
      floatTime: timestamp2.floatTime,
      int: int.int,
      intHex: int.intHex,
      intOct: int.intOct,
      intTime: timestamp2.intTime,
      map: map.map,
      merge: merge.merge,
      null: _null.nullTag,
      omap: omap.omap,
      pairs: pairs.pairs,
      seq: seq.seq,
      set: set.set,
      timestamp: timestamp2.timestamp
    };
    var coreKnownTags = {
      "tag:yaml.org,2002:binary": binary.binary,
      "tag:yaml.org,2002:merge": merge.merge,
      "tag:yaml.org,2002:omap": omap.omap,
      "tag:yaml.org,2002:pairs": pairs.pairs,
      "tag:yaml.org,2002:set": set.set,
      "tag:yaml.org,2002:timestamp": timestamp2.timestamp
    };
    function getTags(customTags, schemaName, addMergeTag) {
      const schemaTags = schemas.get(schemaName);
      if (schemaTags && !customTags) {
        return addMergeTag && !schemaTags.includes(merge.merge) ? schemaTags.concat(merge.merge) : schemaTags.slice();
      }
      let tags = schemaTags;
      if (!tags) {
        if (Array.isArray(customTags))
          tags = [];
        else {
          const keys = Array.from(schemas.keys()).filter((key) => key !== "yaml11").map((key) => JSON.stringify(key)).join(", ");
          throw new Error(`Unknown schema "${schemaName}"; use one of ${keys} or define customTags array`);
        }
      }
      if (Array.isArray(customTags)) {
        for (const tag of customTags)
          tags = tags.concat(tag);
      } else if (typeof customTags === "function") {
        tags = customTags(tags.slice());
      }
      if (addMergeTag)
        tags = tags.concat(merge.merge);
      return tags.reduce((tags2, tag) => {
        const tagObj = typeof tag === "string" ? tagsByName[tag] : tag;
        if (!tagObj) {
          const tagName = JSON.stringify(tag);
          const keys = Object.keys(tagsByName).map((key) => JSON.stringify(key)).join(", ");
          throw new Error(`Unknown custom tag ${tagName}; use one of ${keys}`);
        }
        if (!tags2.includes(tagObj))
          tags2.push(tagObj);
        return tags2;
      }, []);
    }
    exports.coreKnownTags = coreKnownTags;
    exports.getTags = getTags;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/Schema.js
var require_Schema = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/schema/Schema.js"(exports) {
    "use strict";
    var identity = require_identity();
    var map = require_map();
    var seq = require_seq();
    var string = require_string();
    var tags = require_tags();
    var sortMapEntriesByKey = (a, b) => a.key < b.key ? -1 : a.key > b.key ? 1 : 0;
    var Schema = class _Schema {
      constructor({ compat, customTags, merge, resolveKnownTags, schema, sortMapEntries, toStringDefaults }) {
        this.compat = Array.isArray(compat) ? tags.getTags(compat, "compat") : compat ? tags.getTags(null, compat) : null;
        this.name = typeof schema === "string" && schema || "core";
        this.knownTags = resolveKnownTags ? tags.coreKnownTags : {};
        this.tags = tags.getTags(customTags, this.name, merge);
        this.toStringOptions = toStringDefaults ?? null;
        Object.defineProperty(this, identity.MAP, { value: map.map });
        Object.defineProperty(this, identity.SCALAR, { value: string.string });
        Object.defineProperty(this, identity.SEQ, { value: seq.seq });
        this.sortMapEntries = typeof sortMapEntries === "function" ? sortMapEntries : sortMapEntries === true ? sortMapEntriesByKey : null;
      }
      clone() {
        const copy = Object.create(_Schema.prototype, Object.getOwnPropertyDescriptors(this));
        copy.tags = this.tags.slice();
        return copy;
      }
    };
    exports.Schema = Schema;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyDocument.js
var require_stringifyDocument = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/stringify/stringifyDocument.js"(exports) {
    "use strict";
    var identity = require_identity();
    var stringify = require_stringify();
    var stringifyComment = require_stringifyComment();
    function stringifyDocument(doc, options) {
      const lines = [];
      let hasDirectives = options.directives === true;
      if (options.directives !== false && doc.directives) {
        const dir = doc.directives.toString(doc);
        if (dir) {
          lines.push(dir);
          hasDirectives = true;
        } else if (doc.directives.docStart)
          hasDirectives = true;
      }
      if (hasDirectives)
        lines.push("---");
      const ctx = stringify.createStringifyContext(doc, options);
      const { commentString } = ctx.options;
      if (doc.commentBefore) {
        if (lines.length !== 1)
          lines.unshift("");
        const cs = commentString(doc.commentBefore);
        lines.unshift(stringifyComment.indentComment(cs, ""));
      }
      let chompKeep = false;
      let contentComment = null;
      if (doc.contents) {
        if (identity.isNode(doc.contents)) {
          if (doc.contents.spaceBefore && hasDirectives)
            lines.push("");
          if (doc.contents.commentBefore) {
            const cs = commentString(doc.contents.commentBefore);
            lines.push(stringifyComment.indentComment(cs, ""));
          }
          ctx.forceBlockIndent = !!doc.comment;
          contentComment = doc.contents.comment;
        }
        const onChompKeep = contentComment ? void 0 : () => chompKeep = true;
        let body = stringify.stringify(doc.contents, ctx, () => contentComment = null, onChompKeep);
        if (contentComment)
          body += stringifyComment.lineComment(body, "", commentString(contentComment));
        if ((body[0] === "|" || body[0] === ">") && lines[lines.length - 1] === "---") {
          lines[lines.length - 1] = `--- ${body}`;
        } else
          lines.push(body);
      } else {
        lines.push(stringify.stringify(doc.contents, ctx));
      }
      if (doc.directives?.docEnd) {
        if (doc.comment) {
          const cs = commentString(doc.comment);
          if (cs.includes("\n")) {
            lines.push("...");
            lines.push(stringifyComment.indentComment(cs, ""));
          } else {
            lines.push(`... ${cs}`);
          }
        } else {
          lines.push("...");
        }
      } else {
        let dc = doc.comment;
        if (dc && chompKeep)
          dc = dc.replace(/^\n+/, "");
        if (dc) {
          if ((!chompKeep || contentComment) && lines[lines.length - 1] !== "")
            lines.push("");
          lines.push(stringifyComment.indentComment(commentString(dc), ""));
        }
      }
      return lines.join("\n") + "\n";
    }
    exports.stringifyDocument = stringifyDocument;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/doc/Document.js
var require_Document = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/doc/Document.js"(exports) {
    "use strict";
    var Alias = require_Alias();
    var Collection = require_Collection();
    var identity = require_identity();
    var Pair = require_Pair();
    var toJS = require_toJS();
    var Schema = require_Schema();
    var stringifyDocument = require_stringifyDocument();
    var anchors = require_anchors();
    var applyReviver = require_applyReviver();
    var createNode = require_createNode();
    var directives = require_directives();
    var Document = class _Document {
      constructor(value, replacer, options) {
        this.commentBefore = null;
        this.comment = null;
        this.errors = [];
        this.warnings = [];
        Object.defineProperty(this, identity.NODE_TYPE, { value: identity.DOC });
        let _replacer = null;
        if (typeof replacer === "function" || Array.isArray(replacer)) {
          _replacer = replacer;
        } else if (options === void 0 && replacer) {
          options = replacer;
          replacer = void 0;
        }
        const opt = Object.assign({
          intAsBigInt: false,
          keepSourceTokens: false,
          logLevel: "warn",
          prettyErrors: true,
          strict: true,
          stringKeys: false,
          uniqueKeys: true,
          version: "1.2"
        }, options);
        this.options = opt;
        let { version } = opt;
        if (options?._directives) {
          this.directives = options._directives.atDocument();
          if (this.directives.yaml.explicit)
            version = this.directives.yaml.version;
        } else
          this.directives = new directives.Directives({ version });
        this.setSchema(version, options);
        this.contents = value === void 0 ? null : this.createNode(value, _replacer, options);
      }
      /**
       * Create a deep copy of this Document and its contents.
       *
       * Custom Node values that inherit from `Object` still refer to their original instances.
       */
      clone() {
        const copy = Object.create(_Document.prototype, {
          [identity.NODE_TYPE]: { value: identity.DOC }
        });
        copy.commentBefore = this.commentBefore;
        copy.comment = this.comment;
        copy.errors = this.errors.slice();
        copy.warnings = this.warnings.slice();
        copy.options = Object.assign({}, this.options);
        if (this.directives)
          copy.directives = this.directives.clone();
        copy.schema = this.schema.clone();
        copy.contents = identity.isNode(this.contents) ? this.contents.clone(copy.schema) : this.contents;
        if (this.range)
          copy.range = this.range.slice();
        return copy;
      }
      /** Adds a value to the document. */
      add(value) {
        if (assertCollection(this.contents))
          this.contents.add(value);
      }
      /** Adds a value to the document. */
      addIn(path, value) {
        if (assertCollection(this.contents))
          this.contents.addIn(path, value);
      }
      /**
       * Create a new `Alias` node, ensuring that the target `node` has the required anchor.
       *
       * If `node` already has an anchor, `name` is ignored.
       * Otherwise, the `node.anchor` value will be set to `name`,
       * or if an anchor with that name is already present in the document,
       * `name` will be used as a prefix for a new unique anchor.
       * If `name` is undefined, the generated anchor will use 'a' as a prefix.
       */
      createAlias(node, name) {
        if (!node.anchor) {
          const prev = anchors.anchorNames(this);
          node.anchor = // eslint-disable-next-line @typescript-eslint/prefer-nullish-coalescing
          !name || prev.has(name) ? anchors.findNewAnchor(name || "a", prev) : name;
        }
        return new Alias.Alias(node.anchor);
      }
      createNode(value, replacer, options) {
        let _replacer = void 0;
        if (typeof replacer === "function") {
          value = replacer.call({ "": value }, "", value);
          _replacer = replacer;
        } else if (Array.isArray(replacer)) {
          const keyToStr = (v) => typeof v === "number" || v instanceof String || v instanceof Number;
          const asStr = replacer.filter(keyToStr).map(String);
          if (asStr.length > 0)
            replacer = replacer.concat(asStr);
          _replacer = replacer;
        } else if (options === void 0 && replacer) {
          options = replacer;
          replacer = void 0;
        }
        const { aliasDuplicateObjects, anchorPrefix, flow, keepUndefined, onTagObj, tag } = options ?? {};
        const { onAnchor, setAnchors, sourceObjects } = anchors.createNodeAnchors(
          this,
          // eslint-disable-next-line @typescript-eslint/prefer-nullish-coalescing
          anchorPrefix || "a"
        );
        const ctx = {
          aliasDuplicateObjects: aliasDuplicateObjects ?? true,
          keepUndefined: keepUndefined ?? false,
          onAnchor,
          onTagObj,
          replacer: _replacer,
          schema: this.schema,
          sourceObjects
        };
        const node = createNode.createNode(value, tag, ctx);
        if (flow && identity.isCollection(node))
          node.flow = true;
        setAnchors();
        return node;
      }
      /**
       * Convert a key and a value into a `Pair` using the current schema,
       * recursively wrapping all values as `Scalar` or `Collection` nodes.
       */
      createPair(key, value, options = {}) {
        const k = this.createNode(key, null, options);
        const v = this.createNode(value, null, options);
        return new Pair.Pair(k, v);
      }
      /**
       * Removes a value from the document.
       * @returns `true` if the item was found and removed.
       */
      delete(key) {
        return assertCollection(this.contents) ? this.contents.delete(key) : false;
      }
      /**
       * Removes a value from the document.
       * @returns `true` if the item was found and removed.
       */
      deleteIn(path) {
        if (Collection.isEmptyPath(path)) {
          if (this.contents == null)
            return false;
          this.contents = null;
          return true;
        }
        return assertCollection(this.contents) ? this.contents.deleteIn(path) : false;
      }
      /**
       * Returns item at `key`, or `undefined` if not found. By default unwraps
       * scalar values from their surrounding node; to disable set `keepScalar` to
       * `true` (collections are always returned intact).
       */
      get(key, keepScalar) {
        return identity.isCollection(this.contents) ? this.contents.get(key, keepScalar) : void 0;
      }
      /**
       * Returns item at `path`, or `undefined` if not found. By default unwraps
       * scalar values from their surrounding node; to disable set `keepScalar` to
       * `true` (collections are always returned intact).
       */
      getIn(path, keepScalar) {
        if (Collection.isEmptyPath(path))
          return !keepScalar && identity.isScalar(this.contents) ? this.contents.value : this.contents;
        return identity.isCollection(this.contents) ? this.contents.getIn(path, keepScalar) : void 0;
      }
      /**
       * Checks if the document includes a value with the key `key`.
       */
      has(key) {
        return identity.isCollection(this.contents) ? this.contents.has(key) : false;
      }
      /**
       * Checks if the document includes a value at `path`.
       */
      hasIn(path) {
        if (Collection.isEmptyPath(path))
          return this.contents !== void 0;
        return identity.isCollection(this.contents) ? this.contents.hasIn(path) : false;
      }
      /**
       * Sets a value in this document. For `!!set`, `value` needs to be a
       * boolean to add/remove the item from the set.
       */
      set(key, value) {
        if (this.contents == null) {
          this.contents = Collection.collectionFromPath(this.schema, [key], value);
        } else if (assertCollection(this.contents)) {
          this.contents.set(key, value);
        }
      }
      /**
       * Sets a value in this document. For `!!set`, `value` needs to be a
       * boolean to add/remove the item from the set.
       */
      setIn(path, value) {
        if (Collection.isEmptyPath(path)) {
          this.contents = value;
        } else if (this.contents == null) {
          this.contents = Collection.collectionFromPath(this.schema, Array.from(path), value);
        } else if (assertCollection(this.contents)) {
          this.contents.setIn(path, value);
        }
      }
      /**
       * Change the YAML version and schema used by the document.
       * A `null` version disables support for directives, explicit tags, anchors, and aliases.
       * It also requires the `schema` option to be given as a `Schema` instance value.
       *
       * Overrides all previously set schema options.
       */
      setSchema(version, options = {}) {
        if (typeof version === "number")
          version = String(version);
        let opt;
        switch (version) {
          case "1.1":
            if (this.directives)
              this.directives.yaml.version = "1.1";
            else
              this.directives = new directives.Directives({ version: "1.1" });
            opt = { resolveKnownTags: false, schema: "yaml-1.1" };
            break;
          case "1.2":
          case "next":
            if (this.directives)
              this.directives.yaml.version = version;
            else
              this.directives = new directives.Directives({ version });
            opt = { resolveKnownTags: true, schema: "core" };
            break;
          case null:
            if (this.directives)
              delete this.directives;
            opt = null;
            break;
          default: {
            const sv = JSON.stringify(version);
            throw new Error(`Expected '1.1', '1.2' or null as first argument, but found: ${sv}`);
          }
        }
        if (options.schema instanceof Object)
          this.schema = options.schema;
        else if (opt)
          this.schema = new Schema.Schema(Object.assign(opt, options));
        else
          throw new Error(`With a null YAML version, the { schema: Schema } option is required`);
      }
      // json & jsonArg are only used from toJSON()
      toJS({ json, jsonArg, mapAsMap, maxAliasCount, onAnchor, reviver } = {}) {
        const ctx = {
          anchors: /* @__PURE__ */ new Map(),
          doc: this,
          keep: !json,
          mapAsMap: mapAsMap === true,
          mapKeyWarned: false,
          maxAliasCount: typeof maxAliasCount === "number" ? maxAliasCount : 100
        };
        const res = toJS.toJS(this.contents, jsonArg ?? "", ctx);
        if (typeof onAnchor === "function")
          for (const { count, res: res2 } of ctx.anchors.values())
            onAnchor(res2, count);
        return typeof reviver === "function" ? applyReviver.applyReviver(reviver, { "": res }, "", res) : res;
      }
      /**
       * A JSON representation of the document `contents`.
       *
       * @param jsonArg Used by `JSON.stringify` to indicate the array index or
       *   property name.
       */
      toJSON(jsonArg, onAnchor) {
        return this.toJS({ json: true, jsonArg, mapAsMap: false, onAnchor });
      }
      /** A YAML representation of the document. */
      toString(options = {}) {
        if (this.errors.length > 0)
          throw new Error("Document with errors cannot be stringified");
        if ("indent" in options && (!Number.isInteger(options.indent) || Number(options.indent) <= 0)) {
          const s = JSON.stringify(options.indent);
          throw new Error(`"indent" option must be a positive integer, not ${s}`);
        }
        return stringifyDocument.stringifyDocument(this, options);
      }
    };
    function assertCollection(contents) {
      if (identity.isCollection(contents))
        return true;
      throw new Error("Expected a YAML collection as document contents");
    }
    exports.Document = Document;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/errors.js
var require_errors = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/errors.js"(exports) {
    "use strict";
    var YAMLError = class extends Error {
      constructor(name, pos, code, message) {
        super();
        this.name = name;
        this.code = code;
        this.message = message;
        this.pos = pos;
      }
    };
    var YAMLParseError = class extends YAMLError {
      constructor(pos, code, message) {
        super("YAMLParseError", pos, code, message);
      }
    };
    var YAMLWarning = class extends YAMLError {
      constructor(pos, code, message) {
        super("YAMLWarning", pos, code, message);
      }
    };
    var prettifyError = (src, lc) => (error) => {
      if (error.pos[0] === -1)
        return;
      error.linePos = error.pos.map((pos) => lc.linePos(pos));
      const { line, col } = error.linePos[0];
      error.message += ` at line ${line}, column ${col}`;
      let ci = col - 1;
      let lineStr = src.substring(lc.lineStarts[line - 1], lc.lineStarts[line]).replace(/[\n\r]+$/, "");
      if (ci >= 60 && lineStr.length > 80) {
        const trimStart = Math.min(ci - 39, lineStr.length - 79);
        lineStr = "\u2026" + lineStr.substring(trimStart);
        ci -= trimStart - 1;
      }
      if (lineStr.length > 80)
        lineStr = lineStr.substring(0, 79) + "\u2026";
      if (line > 1 && /^ *$/.test(lineStr.substring(0, ci))) {
        let prev = src.substring(lc.lineStarts[line - 2], lc.lineStarts[line - 1]);
        if (prev.length > 80)
          prev = prev.substring(0, 79) + "\u2026\n";
        lineStr = prev + lineStr;
      }
      if (/[^ ]/.test(lineStr)) {
        let count = 1;
        const end = error.linePos[1];
        if (end?.line === line && end.col > col) {
          count = Math.max(1, Math.min(end.col - col, 80 - ci));
        }
        const pointer = " ".repeat(ci) + "^".repeat(count);
        error.message += `:

${lineStr}
${pointer}
`;
      }
    };
    exports.YAMLError = YAMLError;
    exports.YAMLParseError = YAMLParseError;
    exports.YAMLWarning = YAMLWarning;
    exports.prettifyError = prettifyError;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-props.js
var require_resolve_props = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-props.js"(exports) {
    "use strict";
    function resolveProps(tokens, { flow, indicator, next, offset, onError, parentIndent, startOnNewline }) {
      let spaceBefore = false;
      let atNewline = startOnNewline;
      let hasSpace = startOnNewline;
      let comment = "";
      let commentSep = "";
      let hasNewline = false;
      let reqSpace = false;
      let tab = null;
      let anchor = null;
      let tag = null;
      let newlineAfterProp = null;
      let comma = null;
      let found = null;
      let start = null;
      for (const token of tokens) {
        if (reqSpace) {
          if (token.type !== "space" && token.type !== "newline" && token.type !== "comma")
            onError(token.offset, "MISSING_CHAR", "Tags and anchors must be separated from the next token by white space");
          reqSpace = false;
        }
        if (tab) {
          if (atNewline && token.type !== "comment" && token.type !== "newline") {
            onError(tab, "TAB_AS_INDENT", "Tabs are not allowed as indentation");
          }
          tab = null;
        }
        switch (token.type) {
          case "space":
            if (!flow && (indicator !== "doc-start" || next?.type !== "flow-collection") && token.source.includes("	")) {
              tab = token;
            }
            hasSpace = true;
            break;
          case "comment": {
            if (!hasSpace)
              onError(token, "MISSING_CHAR", "Comments must be separated from other tokens by white space characters");
            const cb = token.source.substring(1) || " ";
            if (!comment)
              comment = cb;
            else
              comment += commentSep + cb;
            commentSep = "";
            atNewline = false;
            break;
          }
          case "newline":
            if (atNewline) {
              if (comment)
                comment += token.source;
              else if (!found || indicator !== "seq-item-ind")
                spaceBefore = true;
            } else
              commentSep += token.source;
            atNewline = true;
            hasNewline = true;
            if (anchor || tag)
              newlineAfterProp = token;
            hasSpace = true;
            break;
          case "anchor":
            if (anchor)
              onError(token, "MULTIPLE_ANCHORS", "A node can have at most one anchor");
            if (token.source.endsWith(":"))
              onError(token.offset + token.source.length - 1, "BAD_ALIAS", "Anchor ending in : is ambiguous", true);
            anchor = token;
            start ?? (start = token.offset);
            atNewline = false;
            hasSpace = false;
            reqSpace = true;
            break;
          case "tag": {
            if (tag)
              onError(token, "MULTIPLE_TAGS", "A node can have at most one tag");
            tag = token;
            start ?? (start = token.offset);
            atNewline = false;
            hasSpace = false;
            reqSpace = true;
            break;
          }
          case indicator:
            if (anchor || tag)
              onError(token, "BAD_PROP_ORDER", `Anchors and tags must be after the ${token.source} indicator`);
            if (found)
              onError(token, "UNEXPECTED_TOKEN", `Unexpected ${token.source} in ${flow ?? "collection"}`);
            found = token;
            atNewline = indicator === "seq-item-ind" || indicator === "explicit-key-ind";
            hasSpace = false;
            break;
          case "comma":
            if (flow) {
              if (comma)
                onError(token, "UNEXPECTED_TOKEN", `Unexpected , in ${flow}`);
              comma = token;
              atNewline = false;
              hasSpace = false;
              break;
            }
          // else fallthrough
          default:
            onError(token, "UNEXPECTED_TOKEN", `Unexpected ${token.type} token`);
            atNewline = false;
            hasSpace = false;
        }
      }
      const last = tokens[tokens.length - 1];
      const end = last ? last.offset + last.source.length : offset;
      if (reqSpace && next && next.type !== "space" && next.type !== "newline" && next.type !== "comma" && (next.type !== "scalar" || next.source !== "")) {
        onError(next.offset, "MISSING_CHAR", "Tags and anchors must be separated from the next token by white space");
      }
      if (tab && (atNewline && tab.indent <= parentIndent || next?.type === "block-map" || next?.type === "block-seq"))
        onError(tab, "TAB_AS_INDENT", "Tabs are not allowed as indentation");
      return {
        comma,
        found,
        spaceBefore,
        comment,
        hasNewline,
        anchor,
        tag,
        newlineAfterProp,
        end,
        start: start ?? end
      };
    }
    exports.resolveProps = resolveProps;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/util-contains-newline.js
var require_util_contains_newline = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/util-contains-newline.js"(exports) {
    "use strict";
    function containsNewline(key) {
      if (!key)
        return null;
      switch (key.type) {
        case "alias":
        case "scalar":
        case "double-quoted-scalar":
        case "single-quoted-scalar":
          if (key.source.includes("\n"))
            return true;
          if (key.end) {
            for (const st of key.end)
              if (st.type === "newline")
                return true;
          }
          return false;
        case "flow-collection":
          for (const it of key.items) {
            for (const st of it.start)
              if (st.type === "newline")
                return true;
            if (it.sep) {
              for (const st of it.sep)
                if (st.type === "newline")
                  return true;
            }
            if (containsNewline(it.key) || containsNewline(it.value))
              return true;
          }
          return false;
        default:
          return true;
      }
    }
    exports.containsNewline = containsNewline;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/util-flow-indent-check.js
var require_util_flow_indent_check = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/util-flow-indent-check.js"(exports) {
    "use strict";
    var utilContainsNewline = require_util_contains_newline();
    function flowIndentCheck(indent, fc, onError) {
      if (fc?.type === "flow-collection") {
        const end = fc.end[0];
        if (end.indent === indent && (end.source === "]" || end.source === "}") && utilContainsNewline.containsNewline(fc)) {
          const msg = "Flow end indicator should be more indented than parent";
          onError(end, "BAD_INDENT", msg, true);
        }
      }
    }
    exports.flowIndentCheck = flowIndentCheck;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/util-map-includes.js
var require_util_map_includes = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/util-map-includes.js"(exports) {
    "use strict";
    var identity = require_identity();
    function mapIncludes(ctx, items, search) {
      const { uniqueKeys } = ctx.options;
      if (uniqueKeys === false)
        return false;
      const isEqual = typeof uniqueKeys === "function" ? uniqueKeys : (a, b) => a === b || identity.isScalar(a) && identity.isScalar(b) && a.value === b.value;
      return items.some((pair) => isEqual(pair.key, search));
    }
    exports.mapIncludes = mapIncludes;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-block-map.js
var require_resolve_block_map = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-block-map.js"(exports) {
    "use strict";
    var Pair = require_Pair();
    var YAMLMap = require_YAMLMap();
    var resolveProps = require_resolve_props();
    var utilContainsNewline = require_util_contains_newline();
    var utilFlowIndentCheck = require_util_flow_indent_check();
    var utilMapIncludes = require_util_map_includes();
    var startColMsg = "All mapping items must start at the same column";
    function resolveBlockMap({ composeNode, composeEmptyNode }, ctx, bm, onError, tag) {
      const NodeClass = tag?.nodeClass ?? YAMLMap.YAMLMap;
      const map = new NodeClass(ctx.schema);
      if (ctx.atRoot)
        ctx.atRoot = false;
      let offset = bm.offset;
      let commentEnd = null;
      for (const collItem of bm.items) {
        const { start, key, sep, value } = collItem;
        const keyProps = resolveProps.resolveProps(start, {
          indicator: "explicit-key-ind",
          next: key ?? sep?.[0],
          offset,
          onError,
          parentIndent: bm.indent,
          startOnNewline: true
        });
        const implicitKey = !keyProps.found;
        if (implicitKey) {
          if (key) {
            if (key.type === "block-seq")
              onError(offset, "BLOCK_AS_IMPLICIT_KEY", "A block sequence may not be used as an implicit map key");
            else if ("indent" in key && key.indent !== bm.indent)
              onError(offset, "BAD_INDENT", startColMsg);
          }
          if (!keyProps.anchor && !keyProps.tag && !sep) {
            commentEnd = keyProps.end;
            if (keyProps.comment) {
              if (map.comment)
                map.comment += "\n" + keyProps.comment;
              else
                map.comment = keyProps.comment;
            }
            continue;
          }
          if (keyProps.newlineAfterProp || utilContainsNewline.containsNewline(key)) {
            onError(key ?? start[start.length - 1], "MULTILINE_IMPLICIT_KEY", "Implicit keys need to be on a single line");
          }
        } else if (keyProps.found?.indent !== bm.indent) {
          onError(offset, "BAD_INDENT", startColMsg);
        }
        ctx.atKey = true;
        const keyStart = keyProps.end;
        const keyNode = key ? composeNode(ctx, key, keyProps, onError) : composeEmptyNode(ctx, keyStart, start, null, keyProps, onError);
        if (ctx.schema.compat)
          utilFlowIndentCheck.flowIndentCheck(bm.indent, key, onError);
        ctx.atKey = false;
        if (utilMapIncludes.mapIncludes(ctx, map.items, keyNode))
          onError(keyStart, "DUPLICATE_KEY", "Map keys must be unique");
        const valueProps = resolveProps.resolveProps(sep ?? [], {
          indicator: "map-value-ind",
          next: value,
          offset: keyNode.range[2],
          onError,
          parentIndent: bm.indent,
          startOnNewline: !key || key.type === "block-scalar"
        });
        offset = valueProps.end;
        if (valueProps.found) {
          if (implicitKey) {
            if (value?.type === "block-map" && !valueProps.hasNewline)
              onError(offset, "BLOCK_AS_IMPLICIT_KEY", "Nested mappings are not allowed in compact mappings");
            if (ctx.options.strict && keyProps.start < valueProps.found.offset - 1024)
              onError(keyNode.range, "KEY_OVER_1024_CHARS", "The : indicator must be at most 1024 chars after the start of an implicit block mapping key");
          }
          const valueNode = value ? composeNode(ctx, value, valueProps, onError) : composeEmptyNode(ctx, offset, sep, null, valueProps, onError);
          if (ctx.schema.compat)
            utilFlowIndentCheck.flowIndentCheck(bm.indent, value, onError);
          offset = valueNode.range[2];
          const pair = new Pair.Pair(keyNode, valueNode);
          if (ctx.options.keepSourceTokens)
            pair.srcToken = collItem;
          map.items.push(pair);
        } else {
          if (implicitKey)
            onError(keyNode.range, "MISSING_CHAR", "Implicit map keys need to be followed by map values");
          if (valueProps.comment) {
            if (keyNode.comment)
              keyNode.comment += "\n" + valueProps.comment;
            else
              keyNode.comment = valueProps.comment;
          }
          const pair = new Pair.Pair(keyNode);
          if (ctx.options.keepSourceTokens)
            pair.srcToken = collItem;
          map.items.push(pair);
        }
      }
      if (commentEnd && commentEnd < offset)
        onError(commentEnd, "IMPOSSIBLE", "Map comment with trailing content");
      map.range = [bm.offset, offset, commentEnd ?? offset];
      return map;
    }
    exports.resolveBlockMap = resolveBlockMap;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-block-seq.js
var require_resolve_block_seq = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-block-seq.js"(exports) {
    "use strict";
    var YAMLSeq = require_YAMLSeq();
    var resolveProps = require_resolve_props();
    var utilFlowIndentCheck = require_util_flow_indent_check();
    function resolveBlockSeq({ composeNode, composeEmptyNode }, ctx, bs, onError, tag) {
      const NodeClass = tag?.nodeClass ?? YAMLSeq.YAMLSeq;
      const seq = new NodeClass(ctx.schema);
      if (ctx.atRoot)
        ctx.atRoot = false;
      if (ctx.atKey)
        ctx.atKey = false;
      let offset = bs.offset;
      let commentEnd = null;
      for (const { start, value } of bs.items) {
        const props = resolveProps.resolveProps(start, {
          indicator: "seq-item-ind",
          next: value,
          offset,
          onError,
          parentIndent: bs.indent,
          startOnNewline: true
        });
        if (!props.found) {
          if (props.anchor || props.tag || value) {
            if (value?.type === "block-seq")
              onError(props.end, "BAD_INDENT", "All sequence items must start at the same column");
            else
              onError(offset, "MISSING_CHAR", "Sequence item without - indicator");
          } else {
            commentEnd = props.end;
            if (props.comment)
              seq.comment = props.comment;
            continue;
          }
        }
        const node = value ? composeNode(ctx, value, props, onError) : composeEmptyNode(ctx, props.end, start, null, props, onError);
        if (ctx.schema.compat)
          utilFlowIndentCheck.flowIndentCheck(bs.indent, value, onError);
        offset = node.range[2];
        seq.items.push(node);
      }
      seq.range = [bs.offset, offset, commentEnd ?? offset];
      return seq;
    }
    exports.resolveBlockSeq = resolveBlockSeq;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-end.js
var require_resolve_end = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-end.js"(exports) {
    "use strict";
    function resolveEnd(end, offset, reqSpace, onError) {
      let comment = "";
      if (end) {
        let hasSpace = false;
        let sep = "";
        for (const token of end) {
          const { source, type } = token;
          switch (type) {
            case "space":
              hasSpace = true;
              break;
            case "comment": {
              if (reqSpace && !hasSpace)
                onError(token, "MISSING_CHAR", "Comments must be separated from other tokens by white space characters");
              const cb = source.substring(1) || " ";
              if (!comment)
                comment = cb;
              else
                comment += sep + cb;
              sep = "";
              break;
            }
            case "newline":
              if (comment)
                sep += source;
              hasSpace = true;
              break;
            default:
              onError(token, "UNEXPECTED_TOKEN", `Unexpected ${type} at node end`);
          }
          offset += source.length;
        }
      }
      return { comment, offset };
    }
    exports.resolveEnd = resolveEnd;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-flow-collection.js
var require_resolve_flow_collection = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-flow-collection.js"(exports) {
    "use strict";
    var identity = require_identity();
    var Pair = require_Pair();
    var YAMLMap = require_YAMLMap();
    var YAMLSeq = require_YAMLSeq();
    var resolveEnd = require_resolve_end();
    var resolveProps = require_resolve_props();
    var utilContainsNewline = require_util_contains_newline();
    var utilMapIncludes = require_util_map_includes();
    var blockMsg = "Block collections are not allowed within flow collections";
    var isBlock = (token) => token && (token.type === "block-map" || token.type === "block-seq");
    function resolveFlowCollection({ composeNode, composeEmptyNode }, ctx, fc, onError, tag) {
      const isMap2 = fc.start.source === "{";
      const fcName = isMap2 ? "flow map" : "flow sequence";
      const NodeClass = tag?.nodeClass ?? (isMap2 ? YAMLMap.YAMLMap : YAMLSeq.YAMLSeq);
      const coll = new NodeClass(ctx.schema);
      coll.flow = true;
      const atRoot = ctx.atRoot;
      if (atRoot)
        ctx.atRoot = false;
      if (ctx.atKey)
        ctx.atKey = false;
      let offset = fc.offset + fc.start.source.length;
      for (let i = 0; i < fc.items.length; ++i) {
        const collItem = fc.items[i];
        const { start, key, sep, value } = collItem;
        const props = resolveProps.resolveProps(start, {
          flow: fcName,
          indicator: "explicit-key-ind",
          next: key ?? sep?.[0],
          offset,
          onError,
          parentIndent: fc.indent,
          startOnNewline: false
        });
        if (!props.found) {
          if (!props.anchor && !props.tag && !sep && !value) {
            if (i === 0 && props.comma)
              onError(props.comma, "UNEXPECTED_TOKEN", `Unexpected , in ${fcName}`);
            else if (i < fc.items.length - 1)
              onError(props.start, "UNEXPECTED_TOKEN", `Unexpected empty item in ${fcName}`);
            if (props.comment) {
              if (coll.comment)
                coll.comment += "\n" + props.comment;
              else
                coll.comment = props.comment;
            }
            offset = props.end;
            continue;
          }
          if (!isMap2 && ctx.options.strict && utilContainsNewline.containsNewline(key))
            onError(
              key,
              // checked by containsNewline()
              "MULTILINE_IMPLICIT_KEY",
              "Implicit keys of flow sequence pairs need to be on a single line"
            );
        }
        if (i === 0) {
          if (props.comma)
            onError(props.comma, "UNEXPECTED_TOKEN", `Unexpected , in ${fcName}`);
        } else {
          if (!props.comma)
            onError(props.start, "MISSING_CHAR", `Missing , between ${fcName} items`);
          if (props.comment) {
            let prevItemComment = "";
            loop: for (const st of start) {
              switch (st.type) {
                case "comma":
                case "space":
                  break;
                case "comment":
                  prevItemComment = st.source.substring(1);
                  break loop;
                default:
                  break loop;
              }
            }
            if (prevItemComment) {
              let prev = coll.items[coll.items.length - 1];
              if (identity.isPair(prev))
                prev = prev.value ?? prev.key;
              if (prev.comment)
                prev.comment += "\n" + prevItemComment;
              else
                prev.comment = prevItemComment;
              props.comment = props.comment.substring(prevItemComment.length + 1);
            }
          }
        }
        if (!isMap2 && !sep && !props.found) {
          const valueNode = value ? composeNode(ctx, value, props, onError) : composeEmptyNode(ctx, props.end, sep, null, props, onError);
          coll.items.push(valueNode);
          offset = valueNode.range[2];
          if (isBlock(value))
            onError(valueNode.range, "BLOCK_IN_FLOW", blockMsg);
        } else {
          ctx.atKey = true;
          const keyStart = props.end;
          const keyNode = key ? composeNode(ctx, key, props, onError) : composeEmptyNode(ctx, keyStart, start, null, props, onError);
          if (isBlock(key))
            onError(keyNode.range, "BLOCK_IN_FLOW", blockMsg);
          ctx.atKey = false;
          const valueProps = resolveProps.resolveProps(sep ?? [], {
            flow: fcName,
            indicator: "map-value-ind",
            next: value,
            offset: keyNode.range[2],
            onError,
            parentIndent: fc.indent,
            startOnNewline: false
          });
          if (valueProps.found) {
            if (!isMap2 && !props.found && ctx.options.strict) {
              if (sep)
                for (const st of sep) {
                  if (st === valueProps.found)
                    break;
                  if (st.type === "newline") {
                    onError(st, "MULTILINE_IMPLICIT_KEY", "Implicit keys of flow sequence pairs need to be on a single line");
                    break;
                  }
                }
              if (props.start < valueProps.found.offset - 1024)
                onError(valueProps.found, "KEY_OVER_1024_CHARS", "The : indicator must be at most 1024 chars after the start of an implicit flow sequence key");
            }
          } else if (value) {
            if ("source" in value && value.source?.[0] === ":")
              onError(value, "MISSING_CHAR", `Missing space after : in ${fcName}`);
            else
              onError(valueProps.start, "MISSING_CHAR", `Missing , or : between ${fcName} items`);
          }
          const valueNode = value ? composeNode(ctx, value, valueProps, onError) : valueProps.found ? composeEmptyNode(ctx, valueProps.end, sep, null, valueProps, onError) : null;
          if (valueNode) {
            if (isBlock(value))
              onError(valueNode.range, "BLOCK_IN_FLOW", blockMsg);
          } else if (valueProps.comment) {
            if (keyNode.comment)
              keyNode.comment += "\n" + valueProps.comment;
            else
              keyNode.comment = valueProps.comment;
          }
          const pair = new Pair.Pair(keyNode, valueNode);
          if (ctx.options.keepSourceTokens)
            pair.srcToken = collItem;
          if (isMap2) {
            const map = coll;
            if (utilMapIncludes.mapIncludes(ctx, map.items, keyNode))
              onError(keyStart, "DUPLICATE_KEY", "Map keys must be unique");
            map.items.push(pair);
          } else {
            const map = new YAMLMap.YAMLMap(ctx.schema);
            map.flow = true;
            map.items.push(pair);
            const endRange = (valueNode ?? keyNode).range;
            map.range = [keyNode.range[0], endRange[1], endRange[2]];
            coll.items.push(map);
          }
          offset = valueNode ? valueNode.range[2] : valueProps.end;
        }
      }
      const expectedEnd = isMap2 ? "}" : "]";
      const [ce, ...ee] = fc.end;
      let cePos = offset;
      if (ce?.source === expectedEnd)
        cePos = ce.offset + ce.source.length;
      else {
        const name = fcName[0].toUpperCase() + fcName.substring(1);
        const msg = atRoot ? `${name} must end with a ${expectedEnd}` : `${name} in block collection must be sufficiently indented and end with a ${expectedEnd}`;
        onError(offset, atRoot ? "MISSING_CHAR" : "BAD_INDENT", msg);
        if (ce && ce.source.length !== 1)
          ee.unshift(ce);
      }
      if (ee.length > 0) {
        const end = resolveEnd.resolveEnd(ee, cePos, ctx.options.strict, onError);
        if (end.comment) {
          if (coll.comment)
            coll.comment += "\n" + end.comment;
          else
            coll.comment = end.comment;
        }
        coll.range = [fc.offset, cePos, end.offset];
      } else {
        coll.range = [fc.offset, cePos, cePos];
      }
      return coll;
    }
    exports.resolveFlowCollection = resolveFlowCollection;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/compose-collection.js
var require_compose_collection = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/compose-collection.js"(exports) {
    "use strict";
    var identity = require_identity();
    var Scalar = require_Scalar();
    var YAMLMap = require_YAMLMap();
    var YAMLSeq = require_YAMLSeq();
    var resolveBlockMap = require_resolve_block_map();
    var resolveBlockSeq = require_resolve_block_seq();
    var resolveFlowCollection = require_resolve_flow_collection();
    function resolveCollection(CN, ctx, token, onError, tagName, tag) {
      const coll = token.type === "block-map" ? resolveBlockMap.resolveBlockMap(CN, ctx, token, onError, tag) : token.type === "block-seq" ? resolveBlockSeq.resolveBlockSeq(CN, ctx, token, onError, tag) : resolveFlowCollection.resolveFlowCollection(CN, ctx, token, onError, tag);
      const Coll = coll.constructor;
      if (tagName === "!" || tagName === Coll.tagName) {
        coll.tag = Coll.tagName;
        return coll;
      }
      if (tagName)
        coll.tag = tagName;
      return coll;
    }
    function composeCollection(CN, ctx, token, props, onError) {
      const tagToken = props.tag;
      const tagName = !tagToken ? null : ctx.directives.tagName(tagToken.source, (msg) => onError(tagToken, "TAG_RESOLVE_FAILED", msg));
      if (token.type === "block-seq") {
        const { anchor, newlineAfterProp: nl } = props;
        const lastProp = anchor && tagToken ? anchor.offset > tagToken.offset ? anchor : tagToken : anchor ?? tagToken;
        if (lastProp && (!nl || nl.offset < lastProp.offset)) {
          const message = "Missing newline after block sequence props";
          onError(lastProp, "MISSING_CHAR", message);
        }
      }
      const expType = token.type === "block-map" ? "map" : token.type === "block-seq" ? "seq" : token.start.source === "{" ? "map" : "seq";
      if (!tagToken || !tagName || tagName === "!" || tagName === YAMLMap.YAMLMap.tagName && expType === "map" || tagName === YAMLSeq.YAMLSeq.tagName && expType === "seq") {
        return resolveCollection(CN, ctx, token, onError, tagName);
      }
      let tag = ctx.schema.tags.find((t) => t.tag === tagName && t.collection === expType);
      if (!tag) {
        const kt = ctx.schema.knownTags[tagName];
        if (kt?.collection === expType) {
          ctx.schema.tags.push(Object.assign({}, kt, { default: false }));
          tag = kt;
        } else {
          if (kt) {
            onError(tagToken, "BAD_COLLECTION_TYPE", `${kt.tag} used for ${expType} collection, but expects ${kt.collection ?? "scalar"}`, true);
          } else {
            onError(tagToken, "TAG_RESOLVE_FAILED", `Unresolved tag: ${tagName}`, true);
          }
          return resolveCollection(CN, ctx, token, onError, tagName);
        }
      }
      const coll = resolveCollection(CN, ctx, token, onError, tagName, tag);
      const res = tag.resolve?.(coll, (msg) => onError(tagToken, "TAG_RESOLVE_FAILED", msg), ctx.options) ?? coll;
      const node = identity.isNode(res) ? res : new Scalar.Scalar(res);
      node.range = coll.range;
      node.tag = tagName;
      if (tag?.format)
        node.format = tag.format;
      return node;
    }
    exports.composeCollection = composeCollection;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-block-scalar.js
var require_resolve_block_scalar = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-block-scalar.js"(exports) {
    "use strict";
    var Scalar = require_Scalar();
    function resolveBlockScalar(ctx, scalar, onError) {
      const start = scalar.offset;
      const header = parseBlockScalarHeader(scalar, ctx.options.strict, onError);
      if (!header)
        return { value: "", type: null, comment: "", range: [start, start, start] };
      const type = header.mode === ">" ? Scalar.Scalar.BLOCK_FOLDED : Scalar.Scalar.BLOCK_LITERAL;
      const lines = scalar.source ? splitLines(scalar.source) : [];
      let chompStart = lines.length;
      for (let i = lines.length - 1; i >= 0; --i) {
        const content = lines[i][1];
        if (content === "" || content === "\r")
          chompStart = i;
        else
          break;
      }
      if (chompStart === 0) {
        const value2 = header.chomp === "+" && lines.length > 0 ? "\n".repeat(Math.max(1, lines.length - 1)) : "";
        let end2 = start + header.length;
        if (scalar.source)
          end2 += scalar.source.length;
        return { value: value2, type, comment: header.comment, range: [start, end2, end2] };
      }
      let trimIndent = scalar.indent + header.indent;
      let offset = scalar.offset + header.length;
      let contentStart = 0;
      for (let i = 0; i < chompStart; ++i) {
        const [indent, content] = lines[i];
        if (content === "" || content === "\r") {
          if (header.indent === 0 && indent.length > trimIndent)
            trimIndent = indent.length;
        } else {
          if (indent.length < trimIndent) {
            const message = "Block scalars with more-indented leading empty lines must use an explicit indentation indicator";
            onError(offset + indent.length, "MISSING_CHAR", message);
          }
          if (header.indent === 0)
            trimIndent = indent.length;
          contentStart = i;
          if (trimIndent === 0 && !ctx.atRoot) {
            const message = "Block scalar values in collections must be indented";
            onError(offset, "BAD_INDENT", message);
          }
          break;
        }
        offset += indent.length + content.length + 1;
      }
      for (let i = lines.length - 1; i >= chompStart; --i) {
        if (lines[i][0].length > trimIndent)
          chompStart = i + 1;
      }
      let value = "";
      let sep = "";
      let prevMoreIndented = false;
      for (let i = 0; i < contentStart; ++i)
        value += lines[i][0].slice(trimIndent) + "\n";
      for (let i = contentStart; i < chompStart; ++i) {
        let [indent, content] = lines[i];
        offset += indent.length + content.length + 1;
        const crlf = content[content.length - 1] === "\r";
        if (crlf)
          content = content.slice(0, -1);
        if (content && indent.length < trimIndent) {
          const src = header.indent ? "explicit indentation indicator" : "first line";
          const message = `Block scalar lines must not be less indented than their ${src}`;
          onError(offset - content.length - (crlf ? 2 : 1), "BAD_INDENT", message);
          indent = "";
        }
        if (type === Scalar.Scalar.BLOCK_LITERAL) {
          value += sep + indent.slice(trimIndent) + content;
          sep = "\n";
        } else if (indent.length > trimIndent || content[0] === "	") {
          if (sep === " ")
            sep = "\n";
          else if (!prevMoreIndented && sep === "\n")
            sep = "\n\n";
          value += sep + indent.slice(trimIndent) + content;
          sep = "\n";
          prevMoreIndented = true;
        } else if (content === "") {
          if (sep === "\n")
            value += "\n";
          else
            sep = "\n";
        } else {
          value += sep + content;
          sep = " ";
          prevMoreIndented = false;
        }
      }
      switch (header.chomp) {
        case "-":
          break;
        case "+":
          for (let i = chompStart; i < lines.length; ++i)
            value += "\n" + lines[i][0].slice(trimIndent);
          if (value[value.length - 1] !== "\n")
            value += "\n";
          break;
        default:
          value += "\n";
      }
      const end = start + header.length + scalar.source.length;
      return { value, type, comment: header.comment, range: [start, end, end] };
    }
    function parseBlockScalarHeader({ offset, props }, strict, onError) {
      if (props[0].type !== "block-scalar-header") {
        onError(props[0], "IMPOSSIBLE", "Block scalar header not found");
        return null;
      }
      const { source } = props[0];
      const mode = source[0];
      let indent = 0;
      let chomp = "";
      let error = -1;
      for (let i = 1; i < source.length; ++i) {
        const ch = source[i];
        if (!chomp && (ch === "-" || ch === "+"))
          chomp = ch;
        else {
          const n = Number(ch);
          if (!indent && n)
            indent = n;
          else if (error === -1)
            error = offset + i;
        }
      }
      if (error !== -1)
        onError(error, "UNEXPECTED_TOKEN", `Block scalar header includes extra characters: ${source}`);
      let hasSpace = false;
      let comment = "";
      let length = source.length;
      for (let i = 1; i < props.length; ++i) {
        const token = props[i];
        switch (token.type) {
          case "space":
            hasSpace = true;
          // fallthrough
          case "newline":
            length += token.source.length;
            break;
          case "comment":
            if (strict && !hasSpace) {
              const message = "Comments must be separated from other tokens by white space characters";
              onError(token, "MISSING_CHAR", message);
            }
            length += token.source.length;
            comment = token.source.substring(1);
            break;
          case "error":
            onError(token, "UNEXPECTED_TOKEN", token.message);
            length += token.source.length;
            break;
          /* istanbul ignore next should not happen */
          default: {
            const message = `Unexpected token in block scalar header: ${token.type}`;
            onError(token, "UNEXPECTED_TOKEN", message);
            const ts = token.source;
            if (ts && typeof ts === "string")
              length += ts.length;
          }
        }
      }
      return { mode, indent, chomp, comment, length };
    }
    function splitLines(source) {
      const split = source.split(/\n( *)/);
      const first = split[0];
      const m = first.match(/^( *)/);
      const line0 = m?.[1] ? [m[1], first.slice(m[1].length)] : ["", first];
      const lines = [line0];
      for (let i = 1; i < split.length; i += 2)
        lines.push([split[i], split[i + 1]]);
      return lines;
    }
    exports.resolveBlockScalar = resolveBlockScalar;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-flow-scalar.js
var require_resolve_flow_scalar = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/resolve-flow-scalar.js"(exports) {
    "use strict";
    var Scalar = require_Scalar();
    var resolveEnd = require_resolve_end();
    function resolveFlowScalar(scalar, strict, onError) {
      const { offset, type, source, end } = scalar;
      let _type;
      let value;
      const _onError = (rel, code, msg) => onError(offset + rel, code, msg);
      switch (type) {
        case "scalar":
          _type = Scalar.Scalar.PLAIN;
          value = plainValue(source, _onError);
          break;
        case "single-quoted-scalar":
          _type = Scalar.Scalar.QUOTE_SINGLE;
          value = singleQuotedValue(source, _onError);
          break;
        case "double-quoted-scalar":
          _type = Scalar.Scalar.QUOTE_DOUBLE;
          value = doubleQuotedValue(source, _onError);
          break;
        /* istanbul ignore next should not happen */
        default:
          onError(scalar, "UNEXPECTED_TOKEN", `Expected a flow scalar value, but found: ${type}`);
          return {
            value: "",
            type: null,
            comment: "",
            range: [offset, offset + source.length, offset + source.length]
          };
      }
      const valueEnd = offset + source.length;
      const re = resolveEnd.resolveEnd(end, valueEnd, strict, onError);
      return {
        value,
        type: _type,
        comment: re.comment,
        range: [offset, valueEnd, re.offset]
      };
    }
    function plainValue(source, onError) {
      let badChar = "";
      switch (source[0]) {
        /* istanbul ignore next should not happen */
        case "	":
          badChar = "a tab character";
          break;
        case ",":
          badChar = "flow indicator character ,";
          break;
        case "%":
          badChar = "directive indicator character %";
          break;
        case "|":
        case ">": {
          badChar = `block scalar indicator ${source[0]}`;
          break;
        }
        case "@":
        case "`": {
          badChar = `reserved character ${source[0]}`;
          break;
        }
      }
      if (badChar)
        onError(0, "BAD_SCALAR_START", `Plain value cannot start with ${badChar}`);
      return unfoldLines(source);
    }
    function singleQuotedValue(source, onError) {
      if (source[source.length - 1] !== "'" || source.length === 1)
        onError(source.length, "MISSING_CHAR", "Missing closing 'quote");
      return unfoldLines(source.slice(1, -1)).replace(/''/g, "'");
    }
    function unfoldLines(source) {
      const line = /(.*?)\r?\n/sy;
      let match = line.exec(source);
      if (!match)
        return source;
      let trimEnd, trimBoth;
      try {
        trimEnd = new RegExp("(?<![ 	])[ 	]+$");
        trimBoth = new RegExp("^[ 	]+|(?<![ 	])[ 	]+$", "g");
      } catch {
        trimEnd = /[ \t]+$/;
        trimBoth = /^[ \t]+|[ \t]+$/g;
      }
      let res = match[1].replace(trimEnd, "");
      let sep = " ";
      let pos = line.lastIndex;
      while (match = line.exec(source)) {
        const lm = match[1].replace(trimBoth, "");
        if (lm === "") {
          if (sep === "\n")
            res += sep;
          else
            sep = "\n";
        } else {
          res += sep + lm;
          sep = " ";
        }
        pos = line.lastIndex;
      }
      const last = /[ \t]*(.*)/sy;
      last.lastIndex = pos;
      match = last.exec(source);
      return res + sep + (match?.[1] ?? "");
    }
    function doubleQuotedValue(source, onError) {
      let res = "";
      for (let i = 1; i < source.length - 1; ++i) {
        const ch = source[i];
        if (ch === "\r" && source[i + 1] === "\n")
          continue;
        if (ch === "\n") {
          const { fold, offset } = foldNewline(source, i);
          res += fold;
          i = offset;
        } else if (ch === "\\") {
          let next = source[++i];
          const cc = escapeCodes[next];
          if (cc)
            res += cc;
          else if (next === "\n") {
            next = source[i + 1];
            while (next === " " || next === "	")
              next = source[++i + 1];
          } else if (next === "\r" && source[i + 1] === "\n") {
            next = source[++i + 1];
            while (next === " " || next === "	")
              next = source[++i + 1];
          } else if (next === "x" || next === "u" || next === "U") {
            const length = next === "x" ? 2 : next === "u" ? 4 : 8;
            res += parseCharCode(source, i + 1, length, onError);
            i += length;
          } else {
            const raw = source.substr(i - 1, 2);
            onError(i - 1, "BAD_DQ_ESCAPE", `Invalid escape sequence ${raw}`);
            res += raw;
          }
        } else if (ch === " " || ch === "	") {
          const wsStart = i;
          let next = source[i + 1];
          while (next === " " || next === "	")
            next = source[++i + 1];
          if (next !== "\n" && !(next === "\r" && source[i + 2] === "\n"))
            res += i > wsStart ? source.slice(wsStart, i + 1) : ch;
        } else {
          res += ch;
        }
      }
      if (source[source.length - 1] !== '"' || source.length === 1)
        onError(source.length, "MISSING_CHAR", 'Missing closing "quote');
      return res;
    }
    function foldNewline(source, offset) {
      let fold = "";
      let ch = source[offset + 1];
      while (ch === " " || ch === "	" || ch === "\n" || ch === "\r") {
        if (ch === "\r" && source[offset + 2] !== "\n")
          break;
        if (ch === "\n")
          fold += "\n";
        offset += 1;
        ch = source[offset + 1];
      }
      if (!fold)
        fold = " ";
      return { fold, offset };
    }
    var escapeCodes = {
      "0": "\0",
      // null character
      a: "\x07",
      // bell character
      b: "\b",
      // backspace
      e: "\x1B",
      // escape character
      f: "\f",
      // form feed
      n: "\n",
      // line feed
      r: "\r",
      // carriage return
      t: "	",
      // horizontal tab
      v: "\v",
      // vertical tab
      N: "\x85",
      // Unicode next line
      _: "\xA0",
      // Unicode non-breaking space
      L: "\u2028",
      // Unicode line separator
      P: "\u2029",
      // Unicode paragraph separator
      " ": " ",
      '"': '"',
      "/": "/",
      "\\": "\\",
      "	": "	"
    };
    function parseCharCode(source, offset, length, onError) {
      const cc = source.substr(offset, length);
      const ok = cc.length === length && /^[0-9a-fA-F]+$/.test(cc);
      const code = ok ? parseInt(cc, 16) : NaN;
      try {
        return String.fromCodePoint(code);
      } catch {
        const raw = source.substr(offset - 2, length + 2);
        onError(offset - 2, "BAD_DQ_ESCAPE", `Invalid escape sequence ${raw}`);
        return raw;
      }
    }
    exports.resolveFlowScalar = resolveFlowScalar;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/compose-scalar.js
var require_compose_scalar = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/compose-scalar.js"(exports) {
    "use strict";
    var identity = require_identity();
    var Scalar = require_Scalar();
    var resolveBlockScalar = require_resolve_block_scalar();
    var resolveFlowScalar = require_resolve_flow_scalar();
    function composeScalar(ctx, token, tagToken, onError) {
      const { value, type, comment, range } = token.type === "block-scalar" ? resolveBlockScalar.resolveBlockScalar(ctx, token, onError) : resolveFlowScalar.resolveFlowScalar(token, ctx.options.strict, onError);
      const tagName = tagToken ? ctx.directives.tagName(tagToken.source, (msg) => onError(tagToken, "TAG_RESOLVE_FAILED", msg)) : null;
      let tag;
      if (ctx.options.stringKeys && ctx.atKey) {
        tag = ctx.schema[identity.SCALAR];
      } else if (tagName)
        tag = findScalarTagByName(ctx.schema, value, tagName, tagToken, onError);
      else if (token.type === "scalar")
        tag = findScalarTagByTest(ctx, value, token, onError);
      else
        tag = ctx.schema[identity.SCALAR];
      let scalar;
      try {
        const res = tag.resolve(value, (msg) => onError(tagToken ?? token, "TAG_RESOLVE_FAILED", msg), ctx.options);
        scalar = identity.isScalar(res) ? res : new Scalar.Scalar(res);
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        onError(tagToken ?? token, "TAG_RESOLVE_FAILED", msg);
        scalar = new Scalar.Scalar(value);
      }
      scalar.range = range;
      scalar.source = value;
      if (type)
        scalar.type = type;
      if (tagName)
        scalar.tag = tagName;
      if (tag.format)
        scalar.format = tag.format;
      if (comment)
        scalar.comment = comment;
      return scalar;
    }
    function findScalarTagByName(schema, value, tagName, tagToken, onError) {
      if (tagName === "!")
        return schema[identity.SCALAR];
      const matchWithTest = [];
      for (const tag of schema.tags) {
        if (!tag.collection && tag.tag === tagName) {
          if (tag.default && tag.test)
            matchWithTest.push(tag);
          else
            return tag;
        }
      }
      for (const tag of matchWithTest)
        if (tag.test?.test(value))
          return tag;
      const kt = schema.knownTags[tagName];
      if (kt && !kt.collection) {
        schema.tags.push(Object.assign({}, kt, { default: false, test: void 0 }));
        return kt;
      }
      onError(tagToken, "TAG_RESOLVE_FAILED", `Unresolved tag: ${tagName}`, tagName !== "tag:yaml.org,2002:str");
      return schema[identity.SCALAR];
    }
    function findScalarTagByTest({ atKey, directives, schema }, value, token, onError) {
      const tag = schema.tags.find((tag2) => (tag2.default === true || atKey && tag2.default === "key") && tag2.test?.test(value)) || schema[identity.SCALAR];
      if (schema.compat) {
        const compat = schema.compat.find((tag2) => tag2.default && tag2.test?.test(value)) ?? schema[identity.SCALAR];
        if (tag.tag !== compat.tag) {
          const ts = directives.tagString(tag.tag);
          const cs = directives.tagString(compat.tag);
          const msg = `Value may be parsed as either ${ts} or ${cs}`;
          onError(token, "TAG_RESOLVE_FAILED", msg, true);
        }
      }
      return tag;
    }
    exports.composeScalar = composeScalar;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/util-empty-scalar-position.js
var require_util_empty_scalar_position = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/util-empty-scalar-position.js"(exports) {
    "use strict";
    function emptyScalarPosition(offset, before, pos) {
      if (before) {
        pos ?? (pos = before.length);
        for (let i = pos - 1; i >= 0; --i) {
          let st = before[i];
          switch (st.type) {
            case "space":
            case "comment":
            case "newline":
              offset -= st.source.length;
              continue;
          }
          st = before[++i];
          while (st?.type === "space") {
            offset += st.source.length;
            st = before[++i];
          }
          break;
        }
      }
      return offset;
    }
    exports.emptyScalarPosition = emptyScalarPosition;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/compose-node.js
var require_compose_node = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/compose-node.js"(exports) {
    "use strict";
    var Alias = require_Alias();
    var identity = require_identity();
    var composeCollection = require_compose_collection();
    var composeScalar = require_compose_scalar();
    var resolveEnd = require_resolve_end();
    var utilEmptyScalarPosition = require_util_empty_scalar_position();
    var CN = { composeNode, composeEmptyNode };
    function composeNode(ctx, token, props, onError) {
      const atKey = ctx.atKey;
      const { spaceBefore, comment, anchor, tag } = props;
      let node;
      let isSrcToken = true;
      switch (token.type) {
        case "alias":
          node = composeAlias(ctx, token, onError);
          if (anchor || tag)
            onError(token, "ALIAS_PROPS", "An alias node must not specify any properties");
          break;
        case "scalar":
        case "single-quoted-scalar":
        case "double-quoted-scalar":
        case "block-scalar":
          node = composeScalar.composeScalar(ctx, token, tag, onError);
          if (anchor)
            node.anchor = anchor.source.substring(1);
          break;
        case "block-map":
        case "block-seq":
        case "flow-collection":
          try {
            node = composeCollection.composeCollection(CN, ctx, token, props, onError);
            if (anchor)
              node.anchor = anchor.source.substring(1);
          } catch (error) {
            const message = error instanceof Error ? error.message : String(error);
            onError(token, "RESOURCE_EXHAUSTION", message);
          }
          break;
        default: {
          const message = token.type === "error" ? token.message : `Unsupported token (type: ${token.type})`;
          onError(token, "UNEXPECTED_TOKEN", message);
          isSrcToken = false;
        }
      }
      node ?? (node = composeEmptyNode(ctx, token.offset, void 0, null, props, onError));
      if (anchor && node.anchor === "")
        onError(anchor, "BAD_ALIAS", "Anchor cannot be an empty string");
      if (atKey && ctx.options.stringKeys && (!identity.isScalar(node) || typeof node.value !== "string" || node.tag && node.tag !== "tag:yaml.org,2002:str")) {
        const msg = "With stringKeys, all keys must be strings";
        onError(tag ?? token, "NON_STRING_KEY", msg);
      }
      if (spaceBefore)
        node.spaceBefore = true;
      if (comment) {
        if (token.type === "scalar" && token.source === "")
          node.comment = comment;
        else
          node.commentBefore = comment;
      }
      if (ctx.options.keepSourceTokens && isSrcToken)
        node.srcToken = token;
      return node;
    }
    function composeEmptyNode(ctx, offset, before, pos, { spaceBefore, comment, anchor, tag, end }, onError) {
      const token = {
        type: "scalar",
        offset: utilEmptyScalarPosition.emptyScalarPosition(offset, before, pos),
        indent: -1,
        source: ""
      };
      const node = composeScalar.composeScalar(ctx, token, tag, onError);
      if (anchor) {
        node.anchor = anchor.source.substring(1);
        if (node.anchor === "")
          onError(anchor, "BAD_ALIAS", "Anchor cannot be an empty string");
      }
      if (spaceBefore)
        node.spaceBefore = true;
      if (comment) {
        node.comment = comment;
        node.range[2] = end;
      }
      return node;
    }
    function composeAlias({ options }, { offset, source, end }, onError) {
      const alias = new Alias.Alias(source.substring(1));
      if (alias.source === "")
        onError(offset, "BAD_ALIAS", "Alias cannot be an empty string");
      if (alias.source.endsWith(":"))
        onError(offset + source.length - 1, "BAD_ALIAS", "Alias ending in : is ambiguous", true);
      const valueEnd = offset + source.length;
      const re = resolveEnd.resolveEnd(end, valueEnd, options.strict, onError);
      alias.range = [offset, valueEnd, re.offset];
      if (re.comment)
        alias.comment = re.comment;
      return alias;
    }
    exports.composeEmptyNode = composeEmptyNode;
    exports.composeNode = composeNode;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/compose-doc.js
var require_compose_doc = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/compose-doc.js"(exports) {
    "use strict";
    var Document = require_Document();
    var composeNode = require_compose_node();
    var resolveEnd = require_resolve_end();
    var resolveProps = require_resolve_props();
    function composeDoc(options, directives, { offset, start, value, end }, onError) {
      const opts = Object.assign({ _directives: directives }, options);
      const doc = new Document.Document(void 0, opts);
      const ctx = {
        atKey: false,
        atRoot: true,
        directives: doc.directives,
        options: doc.options,
        schema: doc.schema
      };
      const props = resolveProps.resolveProps(start, {
        indicator: "doc-start",
        next: value ?? end?.[0],
        offset,
        onError,
        parentIndent: 0,
        startOnNewline: true
      });
      if (props.found) {
        doc.directives.docStart = true;
        if (value && (value.type === "block-map" || value.type === "block-seq") && !props.hasNewline)
          onError(props.end, "MISSING_CHAR", "Block collection cannot start on same line with directives-end marker");
      }
      doc.contents = value ? composeNode.composeNode(ctx, value, props, onError) : composeNode.composeEmptyNode(ctx, props.end, start, null, props, onError);
      const contentEnd = doc.contents.range[2];
      const re = resolveEnd.resolveEnd(end, contentEnd, false, onError);
      if (re.comment)
        doc.comment = re.comment;
      doc.range = [offset, contentEnd, re.offset];
      return doc;
    }
    exports.composeDoc = composeDoc;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/composer.js
var require_composer = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/compose/composer.js"(exports) {
    "use strict";
    var node_process = __require("process");
    var directives = require_directives();
    var Document = require_Document();
    var errors = require_errors();
    var identity = require_identity();
    var composeDoc = require_compose_doc();
    var resolveEnd = require_resolve_end();
    function getErrorPos(src) {
      if (typeof src === "number")
        return [src, src + 1];
      if (Array.isArray(src))
        return src.length === 2 ? src : [src[0], src[1]];
      const { offset, source } = src;
      return [offset, offset + (typeof source === "string" ? source.length : 1)];
    }
    function parsePrelude(prelude) {
      let comment = "";
      let atComment = false;
      let afterEmptyLine = false;
      for (let i = 0; i < prelude.length; ++i) {
        const source = prelude[i];
        switch (source[0]) {
          case "#":
            comment += (comment === "" ? "" : afterEmptyLine ? "\n\n" : "\n") + (source.substring(1) || " ");
            atComment = true;
            afterEmptyLine = false;
            break;
          case "%":
            if (prelude[i + 1]?.[0] !== "#")
              i += 1;
            atComment = false;
            break;
          default:
            if (!atComment)
              afterEmptyLine = true;
            atComment = false;
        }
      }
      return { comment, afterEmptyLine };
    }
    var Composer = class {
      constructor(options = {}) {
        this.doc = null;
        this.atDirectives = false;
        this.prelude = [];
        this.errors = [];
        this.warnings = [];
        this.onError = (source, code, message, warning) => {
          const pos = getErrorPos(source);
          if (warning)
            this.warnings.push(new errors.YAMLWarning(pos, code, message));
          else
            this.errors.push(new errors.YAMLParseError(pos, code, message));
        };
        this.directives = new directives.Directives({ version: options.version || "1.2" });
        this.options = options;
      }
      decorate(doc, afterDoc) {
        const { comment, afterEmptyLine } = parsePrelude(this.prelude);
        if (comment) {
          const dc = doc.contents;
          if (afterDoc) {
            doc.comment = doc.comment ? `${doc.comment}
${comment}` : comment;
          } else if (afterEmptyLine || doc.directives.docStart || !dc) {
            doc.commentBefore = comment;
          } else if (identity.isCollection(dc) && !dc.flow && dc.items.length > 0) {
            let it = dc.items[0];
            if (identity.isPair(it))
              it = it.key;
            const cb = it.commentBefore;
            it.commentBefore = cb ? `${comment}
${cb}` : comment;
          } else {
            const cb = dc.commentBefore;
            dc.commentBefore = cb ? `${comment}
${cb}` : comment;
          }
        }
        if (afterDoc) {
          for (let i = 0; i < this.errors.length; ++i)
            doc.errors.push(this.errors[i]);
          for (let i = 0; i < this.warnings.length; ++i)
            doc.warnings.push(this.warnings[i]);
        } else {
          doc.errors = this.errors;
          doc.warnings = this.warnings;
        }
        this.prelude = [];
        this.errors = [];
        this.warnings = [];
      }
      /**
       * Current stream status information.
       *
       * Mostly useful at the end of input for an empty stream.
       */
      streamInfo() {
        return {
          comment: parsePrelude(this.prelude).comment,
          directives: this.directives,
          errors: this.errors,
          warnings: this.warnings
        };
      }
      /**
       * Compose tokens into documents.
       *
       * @param forceDoc - If the stream contains no document, still emit a final document including any comments and directives that would be applied to a subsequent document.
       * @param endOffset - Should be set if `forceDoc` is also set, to set the document range end and to indicate errors correctly.
       */
      *compose(tokens, forceDoc = false, endOffset = -1) {
        for (const token of tokens)
          yield* this.next(token);
        yield* this.end(forceDoc, endOffset);
      }
      /** Advance the composer by one CST token. */
      *next(token) {
        if (node_process.env.LOG_STREAM)
          console.dir(token, { depth: null });
        switch (token.type) {
          case "directive":
            this.directives.add(token.source, (offset, message, warning) => {
              const pos = getErrorPos(token);
              pos[0] += offset;
              this.onError(pos, "BAD_DIRECTIVE", message, warning);
            });
            this.prelude.push(token.source);
            this.atDirectives = true;
            break;
          case "document": {
            const doc = composeDoc.composeDoc(this.options, this.directives, token, this.onError);
            if (this.atDirectives && !doc.directives.docStart)
              this.onError(token, "MISSING_CHAR", "Missing directives-end/doc-start indicator line");
            this.decorate(doc, false);
            if (this.doc)
              yield this.doc;
            this.doc = doc;
            this.atDirectives = false;
            break;
          }
          case "byte-order-mark":
          case "space":
            break;
          case "comment":
          case "newline":
            this.prelude.push(token.source);
            break;
          case "error": {
            const msg = token.source ? `${token.message}: ${JSON.stringify(token.source)}` : token.message;
            const error = new errors.YAMLParseError(getErrorPos(token), "UNEXPECTED_TOKEN", msg);
            if (this.atDirectives || !this.doc)
              this.errors.push(error);
            else
              this.doc.errors.push(error);
            break;
          }
          case "doc-end": {
            if (!this.doc) {
              const msg = "Unexpected doc-end without preceding document";
              this.errors.push(new errors.YAMLParseError(getErrorPos(token), "UNEXPECTED_TOKEN", msg));
              break;
            }
            this.doc.directives.docEnd = true;
            const end = resolveEnd.resolveEnd(token.end, token.offset + token.source.length, this.doc.options.strict, this.onError);
            this.decorate(this.doc, true);
            if (end.comment) {
              const dc = this.doc.comment;
              this.doc.comment = dc ? `${dc}
${end.comment}` : end.comment;
            }
            this.doc.range[2] = end.offset;
            break;
          }
          default:
            this.errors.push(new errors.YAMLParseError(getErrorPos(token), "UNEXPECTED_TOKEN", `Unsupported token ${token.type}`));
        }
      }
      /**
       * Call at end of input to yield any remaining document.
       *
       * @param forceDoc - If the stream contains no document, still emit a final document including any comments and directives that would be applied to a subsequent document.
       * @param endOffset - Should be set if `forceDoc` is also set, to set the document range end and to indicate errors correctly.
       */
      *end(forceDoc = false, endOffset = -1) {
        if (this.doc) {
          this.decorate(this.doc, true);
          yield this.doc;
          this.doc = null;
        } else if (forceDoc) {
          const opts = Object.assign({ _directives: this.directives }, this.options);
          const doc = new Document.Document(void 0, opts);
          if (this.atDirectives)
            this.onError(endOffset, "MISSING_CHAR", "Missing directives-end indicator line");
          doc.range = [0, endOffset, endOffset];
          this.decorate(doc, false);
          yield doc;
        }
      }
    };
    exports.Composer = Composer;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/cst-scalar.js
var require_cst_scalar = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/cst-scalar.js"(exports) {
    "use strict";
    var resolveBlockScalar = require_resolve_block_scalar();
    var resolveFlowScalar = require_resolve_flow_scalar();
    var errors = require_errors();
    var stringifyString = require_stringifyString();
    function resolveAsScalar(token, strict = true, onError) {
      if (token) {
        const _onError = (pos, code, message) => {
          const offset = typeof pos === "number" ? pos : Array.isArray(pos) ? pos[0] : pos.offset;
          if (onError)
            onError(offset, code, message);
          else
            throw new errors.YAMLParseError([offset, offset + 1], code, message);
        };
        switch (token.type) {
          case "scalar":
          case "single-quoted-scalar":
          case "double-quoted-scalar":
            return resolveFlowScalar.resolveFlowScalar(token, strict, _onError);
          case "block-scalar":
            return resolveBlockScalar.resolveBlockScalar({ options: { strict } }, token, _onError);
        }
      }
      return null;
    }
    function createScalarToken(value, context) {
      const { implicitKey = false, indent, inFlow = false, offset = -1, type = "PLAIN" } = context;
      const source = stringifyString.stringifyString({ type, value }, {
        implicitKey,
        indent: indent > 0 ? " ".repeat(indent) : "",
        inFlow,
        options: { blockQuote: true, lineWidth: -1 }
      });
      const end = context.end ?? [
        { type: "newline", offset: -1, indent, source: "\n" }
      ];
      switch (source[0]) {
        case "|":
        case ">": {
          const he = source.indexOf("\n");
          const head = source.substring(0, he);
          const body = source.substring(he + 1) + "\n";
          const props = [
            { type: "block-scalar-header", offset, indent, source: head }
          ];
          if (!addEndtoBlockProps(props, end))
            props.push({ type: "newline", offset: -1, indent, source: "\n" });
          return { type: "block-scalar", offset, indent, props, source: body };
        }
        case '"':
          return { type: "double-quoted-scalar", offset, indent, source, end };
        case "'":
          return { type: "single-quoted-scalar", offset, indent, source, end };
        default:
          return { type: "scalar", offset, indent, source, end };
      }
    }
    function setScalarValue(token, value, context = {}) {
      let { afterKey = false, implicitKey = false, inFlow = false, type } = context;
      let indent = "indent" in token ? token.indent : null;
      if (afterKey && typeof indent === "number")
        indent += 2;
      if (!type)
        switch (token.type) {
          case "single-quoted-scalar":
            type = "QUOTE_SINGLE";
            break;
          case "double-quoted-scalar":
            type = "QUOTE_DOUBLE";
            break;
          case "block-scalar": {
            const header = token.props[0];
            if (header.type !== "block-scalar-header")
              throw new Error("Invalid block scalar header");
            type = header.source[0] === ">" ? "BLOCK_FOLDED" : "BLOCK_LITERAL";
            break;
          }
          default:
            type = "PLAIN";
        }
      const source = stringifyString.stringifyString({ type, value }, {
        implicitKey: implicitKey || indent === null,
        indent: indent !== null && indent > 0 ? " ".repeat(indent) : "",
        inFlow,
        options: { blockQuote: true, lineWidth: -1 }
      });
      switch (source[0]) {
        case "|":
        case ">":
          setBlockScalarValue(token, source);
          break;
        case '"':
          setFlowScalarValue(token, source, "double-quoted-scalar");
          break;
        case "'":
          setFlowScalarValue(token, source, "single-quoted-scalar");
          break;
        default:
          setFlowScalarValue(token, source, "scalar");
      }
    }
    function setBlockScalarValue(token, source) {
      const he = source.indexOf("\n");
      const head = source.substring(0, he);
      const body = source.substring(he + 1) + "\n";
      if (token.type === "block-scalar") {
        const header = token.props[0];
        if (header.type !== "block-scalar-header")
          throw new Error("Invalid block scalar header");
        header.source = head;
        token.source = body;
      } else {
        const { offset } = token;
        const indent = "indent" in token ? token.indent : -1;
        const props = [
          { type: "block-scalar-header", offset, indent, source: head }
        ];
        if (!addEndtoBlockProps(props, "end" in token ? token.end : void 0))
          props.push({ type: "newline", offset: -1, indent, source: "\n" });
        for (const key of Object.keys(token))
          if (key !== "type" && key !== "offset")
            delete token[key];
        Object.assign(token, { type: "block-scalar", indent, props, source: body });
      }
    }
    function addEndtoBlockProps(props, end) {
      if (end)
        for (const st of end)
          switch (st.type) {
            case "space":
            case "comment":
              props.push(st);
              break;
            case "newline":
              props.push(st);
              return true;
          }
      return false;
    }
    function setFlowScalarValue(token, source, type) {
      switch (token.type) {
        case "scalar":
        case "double-quoted-scalar":
        case "single-quoted-scalar":
          token.type = type;
          token.source = source;
          break;
        case "block-scalar": {
          const end = token.props.slice(1);
          let oa = source.length;
          if (token.props[0].type === "block-scalar-header")
            oa -= token.props[0].source.length;
          for (const tok of end)
            tok.offset += oa;
          delete token.props;
          Object.assign(token, { type, source, end });
          break;
        }
        case "block-map":
        case "block-seq": {
          const offset = token.offset + source.length;
          const nl = { type: "newline", offset, indent: token.indent, source: "\n" };
          delete token.items;
          Object.assign(token, { type, source, end: [nl] });
          break;
        }
        default: {
          const indent = "indent" in token ? token.indent : -1;
          const end = "end" in token && Array.isArray(token.end) ? token.end.filter((st) => st.type === "space" || st.type === "comment" || st.type === "newline") : [];
          for (const key of Object.keys(token))
            if (key !== "type" && key !== "offset")
              delete token[key];
          Object.assign(token, { type, indent, source, end });
        }
      }
    }
    exports.createScalarToken = createScalarToken;
    exports.resolveAsScalar = resolveAsScalar;
    exports.setScalarValue = setScalarValue;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/cst-stringify.js
var require_cst_stringify = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/cst-stringify.js"(exports) {
    "use strict";
    var stringify = (cst) => "type" in cst ? stringifyToken(cst) : stringifyItem(cst);
    function stringifyToken(token) {
      switch (token.type) {
        case "block-scalar": {
          let res = "";
          for (const tok of token.props)
            res += stringifyToken(tok);
          return res + token.source;
        }
        case "block-map":
        case "block-seq": {
          let res = "";
          for (const item of token.items)
            res += stringifyItem(item);
          return res;
        }
        case "flow-collection": {
          let res = token.start.source;
          for (const item of token.items)
            res += stringifyItem(item);
          for (const st of token.end)
            res += st.source;
          return res;
        }
        case "document": {
          let res = stringifyItem(token);
          if (token.end)
            for (const st of token.end)
              res += st.source;
          return res;
        }
        default: {
          let res = token.source;
          if ("end" in token && token.end)
            for (const st of token.end)
              res += st.source;
          return res;
        }
      }
    }
    function stringifyItem({ start, key, sep, value }) {
      let res = "";
      for (const st of start)
        res += st.source;
      if (key)
        res += stringifyToken(key);
      if (sep)
        for (const st of sep)
          res += st.source;
      if (value)
        res += stringifyToken(value);
      return res;
    }
    exports.stringify = stringify;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/cst-visit.js
var require_cst_visit = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/cst-visit.js"(exports) {
    "use strict";
    var BREAK = Symbol("break visit");
    var SKIP = Symbol("skip children");
    var REMOVE = Symbol("remove item");
    function visit(cst, visitor) {
      if ("type" in cst && cst.type === "document")
        cst = { start: cst.start, value: cst.value };
      _visit(Object.freeze([]), cst, visitor);
    }
    visit.BREAK = BREAK;
    visit.SKIP = SKIP;
    visit.REMOVE = REMOVE;
    visit.itemAtPath = (cst, path) => {
      let item = cst;
      for (const [field, index] of path) {
        const tok = item?.[field];
        if (tok && "items" in tok) {
          item = tok.items[index];
        } else
          return void 0;
      }
      return item;
    };
    visit.parentCollection = (cst, path) => {
      const parent = visit.itemAtPath(cst, path.slice(0, -1));
      const field = path[path.length - 1][0];
      const coll = parent?.[field];
      if (coll && "items" in coll)
        return coll;
      throw new Error("Parent collection not found");
    };
    function _visit(path, item, visitor) {
      let ctrl = visitor(item, path);
      if (typeof ctrl === "symbol")
        return ctrl;
      for (const field of ["key", "value"]) {
        const token = item[field];
        if (token && "items" in token) {
          for (let i = 0; i < token.items.length; ++i) {
            const ci = _visit(Object.freeze(path.concat([[field, i]])), token.items[i], visitor);
            if (typeof ci === "number")
              i = ci - 1;
            else if (ci === BREAK)
              return BREAK;
            else if (ci === REMOVE) {
              token.items.splice(i, 1);
              i -= 1;
            }
          }
          if (typeof ctrl === "function" && field === "key")
            ctrl = ctrl(item, path);
        }
      }
      return typeof ctrl === "function" ? ctrl(item, path) : ctrl;
    }
    exports.visit = visit;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/cst.js
var require_cst = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/cst.js"(exports) {
    "use strict";
    var cstScalar = require_cst_scalar();
    var cstStringify = require_cst_stringify();
    var cstVisit = require_cst_visit();
    var BOM = "\uFEFF";
    var DOCUMENT = "";
    var FLOW_END = "";
    var SCALAR = "";
    var isCollection = (token) => !!token && "items" in token;
    var isScalar = (token) => !!token && (token.type === "scalar" || token.type === "single-quoted-scalar" || token.type === "double-quoted-scalar" || token.type === "block-scalar");
    function prettyToken(token) {
      switch (token) {
        case BOM:
          return "<BOM>";
        case DOCUMENT:
          return "<DOC>";
        case FLOW_END:
          return "<FLOW_END>";
        case SCALAR:
          return "<SCALAR>";
        default:
          return JSON.stringify(token);
      }
    }
    function tokenType(source) {
      switch (source) {
        case BOM:
          return "byte-order-mark";
        case DOCUMENT:
          return "doc-mode";
        case FLOW_END:
          return "flow-error-end";
        case SCALAR:
          return "scalar";
        case "---":
          return "doc-start";
        case "...":
          return "doc-end";
        case "":
        case "\n":
        case "\r\n":
          return "newline";
        case "-":
          return "seq-item-ind";
        case "?":
          return "explicit-key-ind";
        case ":":
          return "map-value-ind";
        case "{":
          return "flow-map-start";
        case "}":
          return "flow-map-end";
        case "[":
          return "flow-seq-start";
        case "]":
          return "flow-seq-end";
        case ",":
          return "comma";
      }
      switch (source[0]) {
        case " ":
        case "	":
          return "space";
        case "#":
          return "comment";
        case "%":
          return "directive-line";
        case "*":
          return "alias";
        case "&":
          return "anchor";
        case "!":
          return "tag";
        case "'":
          return "single-quoted-scalar";
        case '"':
          return "double-quoted-scalar";
        case "|":
        case ">":
          return "block-scalar-header";
      }
      return null;
    }
    exports.createScalarToken = cstScalar.createScalarToken;
    exports.resolveAsScalar = cstScalar.resolveAsScalar;
    exports.setScalarValue = cstScalar.setScalarValue;
    exports.stringify = cstStringify.stringify;
    exports.visit = cstVisit.visit;
    exports.BOM = BOM;
    exports.DOCUMENT = DOCUMENT;
    exports.FLOW_END = FLOW_END;
    exports.SCALAR = SCALAR;
    exports.isCollection = isCollection;
    exports.isScalar = isScalar;
    exports.prettyToken = prettyToken;
    exports.tokenType = tokenType;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/lexer.js
var require_lexer = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/lexer.js"(exports) {
    "use strict";
    var cst = require_cst();
    function isEmpty(ch) {
      switch (ch) {
        case void 0:
        case " ":
        case "\n":
        case "\r":
        case "	":
          return true;
        default:
          return false;
      }
    }
    var hexDigits = new Set("0123456789ABCDEFabcdef");
    var tagChars = new Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-#;/?:@&=+$_.!~*'()");
    var flowIndicatorChars = new Set(",[]{}");
    var invalidAnchorChars = new Set(" ,[]{}\n\r	");
    var isNotAnchorChar = (ch) => !ch || invalidAnchorChars.has(ch);
    var Lexer = class {
      constructor() {
        this.atEnd = false;
        this.blockScalarIndent = -1;
        this.blockScalarKeep = false;
        this.buffer = "";
        this.flowKey = false;
        this.flowLevel = 0;
        this.indentNext = 0;
        this.indentValue = 0;
        this.lineEndPos = null;
        this.next = null;
        this.pos = 0;
      }
      /**
       * Generate YAML tokens from the `source` string. If `incomplete`,
       * a part of the last line may be left as a buffer for the next call.
       *
       * @returns A generator of lexical tokens
       */
      *lex(source, incomplete = false) {
        if (source) {
          if (typeof source !== "string")
            throw TypeError("source is not a string");
          this.buffer = this.buffer ? this.buffer + source : source;
          this.lineEndPos = null;
        }
        this.atEnd = !incomplete;
        let next = this.next ?? "stream";
        while (next && (incomplete || this.hasChars(1)))
          next = yield* this.parseNext(next);
      }
      atLineEnd() {
        let i = this.pos;
        let ch = this.buffer[i];
        while (ch === " " || ch === "	")
          ch = this.buffer[++i];
        if (!ch || ch === "#" || ch === "\n")
          return true;
        if (ch === "\r")
          return this.buffer[i + 1] === "\n";
        return false;
      }
      charAt(n) {
        return this.buffer[this.pos + n];
      }
      continueScalar(offset) {
        let ch = this.buffer[offset];
        if (this.indentNext > 0) {
          let indent = 0;
          while (ch === " ")
            ch = this.buffer[++indent + offset];
          if (ch === "\r") {
            const next = this.buffer[indent + offset + 1];
            if (next === "\n" || !next && !this.atEnd)
              return offset + indent + 1;
          }
          return ch === "\n" || indent >= this.indentNext || !ch && !this.atEnd ? offset + indent : -1;
        }
        if (ch === "-" || ch === ".") {
          const dt = this.buffer.substr(offset, 3);
          if ((dt === "---" || dt === "...") && isEmpty(this.buffer[offset + 3]))
            return -1;
        }
        return offset;
      }
      getLine() {
        let end = this.lineEndPos;
        if (typeof end !== "number" || end !== -1 && end < this.pos) {
          end = this.buffer.indexOf("\n", this.pos);
          this.lineEndPos = end;
        }
        if (end === -1)
          return this.atEnd ? this.buffer.substring(this.pos) : null;
        if (this.buffer[end - 1] === "\r")
          end -= 1;
        return this.buffer.substring(this.pos, end);
      }
      hasChars(n) {
        return this.pos + n <= this.buffer.length;
      }
      setNext(state) {
        this.buffer = this.buffer.substring(this.pos);
        this.pos = 0;
        this.lineEndPos = null;
        this.next = state;
        return null;
      }
      peek(n) {
        return this.buffer.substr(this.pos, n);
      }
      *parseNext(next) {
        switch (next) {
          case "stream":
            return yield* this.parseStream();
          case "line-start":
            return yield* this.parseLineStart();
          case "block-start":
            return yield* this.parseBlockStart();
          case "doc":
            return yield* this.parseDocument();
          case "flow":
            return yield* this.parseFlowCollection();
          case "quoted-scalar":
            return yield* this.parseQuotedScalar();
          case "block-scalar":
            return yield* this.parseBlockScalar();
          case "plain-scalar":
            return yield* this.parsePlainScalar();
        }
      }
      *parseStream() {
        let line = this.getLine();
        if (line === null)
          return this.setNext("stream");
        if (line[0] === cst.BOM) {
          yield* this.pushCount(1);
          line = line.substring(1);
        }
        if (line[0] === "%") {
          let dirEnd = line.length;
          let cs = line.indexOf("#");
          while (cs !== -1) {
            const ch = line[cs - 1];
            if (ch === " " || ch === "	") {
              dirEnd = cs - 1;
              break;
            } else {
              cs = line.indexOf("#", cs + 1);
            }
          }
          while (true) {
            const ch = line[dirEnd - 1];
            if (ch === " " || ch === "	")
              dirEnd -= 1;
            else
              break;
          }
          const n = (yield* this.pushCount(dirEnd)) + (yield* this.pushSpaces(true));
          yield* this.pushCount(line.length - n);
          this.pushNewline();
          return "stream";
        }
        if (this.atLineEnd()) {
          const sp = yield* this.pushSpaces(true);
          yield* this.pushCount(line.length - sp);
          yield* this.pushNewline();
          return "stream";
        }
        yield cst.DOCUMENT;
        return yield* this.parseLineStart();
      }
      *parseLineStart() {
        const ch = this.charAt(0);
        if (!ch && !this.atEnd)
          return this.setNext("line-start");
        if (ch === "-" || ch === ".") {
          if (!this.atEnd && !this.hasChars(4))
            return this.setNext("line-start");
          const s = this.peek(3);
          if ((s === "---" || s === "...") && isEmpty(this.charAt(3))) {
            yield* this.pushCount(3);
            this.indentValue = 0;
            this.indentNext = 0;
            return s === "---" ? "doc" : "stream";
          }
        }
        this.indentValue = yield* this.pushSpaces(false);
        if (this.indentNext > this.indentValue && !isEmpty(this.charAt(1)))
          this.indentNext = this.indentValue;
        return yield* this.parseBlockStart();
      }
      *parseBlockStart() {
        const [ch0, ch1] = this.peek(2);
        if (!ch1 && !this.atEnd)
          return this.setNext("block-start");
        if ((ch0 === "-" || ch0 === "?" || ch0 === ":") && isEmpty(ch1)) {
          const n = (yield* this.pushCount(1)) + (yield* this.pushSpaces(true));
          this.indentNext = this.indentValue + 1;
          this.indentValue += n;
          return "block-start";
        }
        return "doc";
      }
      *parseDocument() {
        yield* this.pushSpaces(true);
        const line = this.getLine();
        if (line === null)
          return this.setNext("doc");
        let n = yield* this.pushIndicators();
        switch (line[n]) {
          case "#":
            yield* this.pushCount(line.length - n);
          // fallthrough
          case void 0:
            yield* this.pushNewline();
            return yield* this.parseLineStart();
          case "{":
          case "[":
            yield* this.pushCount(1);
            this.flowKey = false;
            this.flowLevel = 1;
            return "flow";
          case "}":
          case "]":
            yield* this.pushCount(1);
            return "doc";
          case "*":
            yield* this.pushUntil(isNotAnchorChar);
            return "doc";
          case '"':
          case "'":
            return yield* this.parseQuotedScalar();
          case "|":
          case ">":
            n += yield* this.parseBlockScalarHeader();
            n += yield* this.pushSpaces(true);
            yield* this.pushCount(line.length - n);
            yield* this.pushNewline();
            return yield* this.parseBlockScalar();
          default:
            return yield* this.parsePlainScalar();
        }
      }
      *parseFlowCollection() {
        let nl, sp;
        let indent = -1;
        do {
          nl = yield* this.pushNewline();
          if (nl > 0) {
            sp = yield* this.pushSpaces(false);
            this.indentValue = indent = sp;
          } else {
            sp = 0;
          }
          sp += yield* this.pushSpaces(true);
        } while (nl + sp > 0);
        const line = this.getLine();
        if (line === null)
          return this.setNext("flow");
        if (indent !== -1 && indent < this.indentNext && line[0] !== "#" || indent === 0 && (line.startsWith("---") || line.startsWith("...")) && isEmpty(line[3])) {
          const atFlowEndMarker = indent === this.indentNext - 1 && this.flowLevel === 1 && (line[0] === "]" || line[0] === "}");
          if (!atFlowEndMarker) {
            this.flowLevel = 0;
            yield cst.FLOW_END;
            return yield* this.parseLineStart();
          }
        }
        let n = 0;
        while (line[n] === ",") {
          n += yield* this.pushCount(1);
          n += yield* this.pushSpaces(true);
          this.flowKey = false;
        }
        n += yield* this.pushIndicators();
        switch (line[n]) {
          case void 0:
            return "flow";
          case "#":
            yield* this.pushCount(line.length - n);
            return "flow";
          case "{":
          case "[":
            yield* this.pushCount(1);
            this.flowKey = false;
            this.flowLevel += 1;
            return "flow";
          case "}":
          case "]":
            yield* this.pushCount(1);
            this.flowKey = true;
            this.flowLevel -= 1;
            return this.flowLevel ? "flow" : "doc";
          case "*":
            yield* this.pushUntil(isNotAnchorChar);
            return "flow";
          case '"':
          case "'":
            this.flowKey = true;
            return yield* this.parseQuotedScalar();
          case ":": {
            const next = this.charAt(1);
            if (this.flowKey || isEmpty(next) || next === ",") {
              this.flowKey = false;
              yield* this.pushCount(1);
              yield* this.pushSpaces(true);
              return "flow";
            }
          }
          // fallthrough
          default:
            this.flowKey = false;
            return yield* this.parsePlainScalar();
        }
      }
      *parseQuotedScalar() {
        const quote = this.charAt(0);
        let end = this.buffer.indexOf(quote, this.pos + 1);
        if (quote === "'") {
          while (end !== -1 && this.buffer[end + 1] === "'")
            end = this.buffer.indexOf("'", end + 2);
        } else {
          while (end !== -1) {
            let n = 0;
            while (this.buffer[end - 1 - n] === "\\")
              n += 1;
            if (n % 2 === 0)
              break;
            end = this.buffer.indexOf('"', end + 1);
          }
        }
        const qb = this.buffer.substring(0, end);
        let nl = qb.indexOf("\n", this.pos);
        if (nl !== -1) {
          while (nl !== -1) {
            const cs = this.continueScalar(nl + 1);
            if (cs === -1)
              break;
            nl = qb.indexOf("\n", cs);
          }
          if (nl !== -1) {
            end = nl - (qb[nl - 1] === "\r" ? 2 : 1);
          }
        }
        if (end === -1) {
          if (!this.atEnd)
            return this.setNext("quoted-scalar");
          end = this.buffer.length;
        }
        yield* this.pushToIndex(end + 1, false);
        return this.flowLevel ? "flow" : "doc";
      }
      *parseBlockScalarHeader() {
        this.blockScalarIndent = -1;
        this.blockScalarKeep = false;
        let i = this.pos;
        while (true) {
          const ch = this.buffer[++i];
          if (ch === "+")
            this.blockScalarKeep = true;
          else if (ch > "0" && ch <= "9")
            this.blockScalarIndent = Number(ch) - 1;
          else if (ch !== "-")
            break;
        }
        return yield* this.pushUntil((ch) => isEmpty(ch) || ch === "#");
      }
      *parseBlockScalar() {
        let nl = this.pos - 1;
        let indent = 0;
        let ch;
        loop: for (let i2 = this.pos; ch = this.buffer[i2]; ++i2) {
          switch (ch) {
            case " ":
              indent += 1;
              break;
            case "\n":
              nl = i2;
              indent = 0;
              break;
            case "\r": {
              const next = this.buffer[i2 + 1];
              if (!next && !this.atEnd)
                return this.setNext("block-scalar");
              if (next === "\n")
                break;
            }
            // fallthrough
            default:
              break loop;
          }
        }
        if (!ch && !this.atEnd)
          return this.setNext("block-scalar");
        if (indent >= this.indentNext) {
          if (this.blockScalarIndent === -1)
            this.indentNext = indent;
          else {
            this.indentNext = this.blockScalarIndent + (this.indentNext === 0 ? 1 : this.indentNext);
          }
          do {
            const cs = this.continueScalar(nl + 1);
            if (cs === -1)
              break;
            nl = this.buffer.indexOf("\n", cs);
          } while (nl !== -1);
          if (nl === -1) {
            if (!this.atEnd)
              return this.setNext("block-scalar");
            nl = this.buffer.length;
          }
        }
        let i = nl + 1;
        ch = this.buffer[i];
        while (ch === " ")
          ch = this.buffer[++i];
        if (ch === "	") {
          while (ch === "	" || ch === " " || ch === "\r" || ch === "\n")
            ch = this.buffer[++i];
          nl = i - 1;
        } else if (!this.blockScalarKeep) {
          do {
            let i2 = nl - 1;
            let ch2 = this.buffer[i2];
            if (ch2 === "\r")
              ch2 = this.buffer[--i2];
            const lastChar = i2;
            while (ch2 === " ")
              ch2 = this.buffer[--i2];
            if (ch2 === "\n" && i2 >= this.pos && i2 + 1 + indent > lastChar)
              nl = i2;
            else
              break;
          } while (true);
        }
        yield cst.SCALAR;
        yield* this.pushToIndex(nl + 1, true);
        return yield* this.parseLineStart();
      }
      *parsePlainScalar() {
        const inFlow = this.flowLevel > 0;
        let end = this.pos - 1;
        let i = this.pos - 1;
        let ch;
        while (ch = this.buffer[++i]) {
          if (ch === ":") {
            const next = this.buffer[i + 1];
            if (isEmpty(next) || inFlow && flowIndicatorChars.has(next))
              break;
            end = i;
          } else if (isEmpty(ch)) {
            let next = this.buffer[i + 1];
            if (ch === "\r") {
              if (next === "\n") {
                i += 1;
                ch = "\n";
                next = this.buffer[i + 1];
              } else
                end = i;
            }
            if (next === "#" || inFlow && flowIndicatorChars.has(next))
              break;
            if (ch === "\n") {
              const cs = this.continueScalar(i + 1);
              if (cs === -1)
                break;
              i = Math.max(i, cs - 2);
            }
          } else {
            if (inFlow && flowIndicatorChars.has(ch))
              break;
            end = i;
          }
        }
        if (!ch && !this.atEnd)
          return this.setNext("plain-scalar");
        yield cst.SCALAR;
        yield* this.pushToIndex(end + 1, true);
        return inFlow ? "flow" : "doc";
      }
      *pushCount(n) {
        if (n > 0) {
          yield this.buffer.substr(this.pos, n);
          this.pos += n;
          return n;
        }
        return 0;
      }
      *pushToIndex(i, allowEmpty) {
        const s = this.buffer.slice(this.pos, i);
        if (s) {
          yield s;
          this.pos += s.length;
          return s.length;
        } else if (allowEmpty)
          yield "";
        return 0;
      }
      *pushIndicators() {
        let n = 0;
        loop: while (true) {
          switch (this.charAt(0)) {
            case "!":
              n += yield* this.pushTag();
              n += yield* this.pushSpaces(true);
              continue loop;
            case "&":
              n += yield* this.pushUntil(isNotAnchorChar);
              n += yield* this.pushSpaces(true);
              continue loop;
            case "-":
            // this is an error
            case "?":
            // this is an error outside flow collections
            case ":": {
              const inFlow = this.flowLevel > 0;
              const ch1 = this.charAt(1);
              if (isEmpty(ch1) || inFlow && flowIndicatorChars.has(ch1)) {
                if (!inFlow)
                  this.indentNext = this.indentValue + 1;
                else if (this.flowKey)
                  this.flowKey = false;
                n += yield* this.pushCount(1);
                n += yield* this.pushSpaces(true);
                continue loop;
              }
            }
          }
          break loop;
        }
        return n;
      }
      *pushTag() {
        if (this.charAt(1) === "<") {
          let i = this.pos + 2;
          let ch = this.buffer[i];
          while (!isEmpty(ch) && ch !== ">")
            ch = this.buffer[++i];
          return yield* this.pushToIndex(ch === ">" ? i + 1 : i, false);
        } else {
          let i = this.pos + 1;
          let ch = this.buffer[i];
          while (ch) {
            if (tagChars.has(ch))
              ch = this.buffer[++i];
            else if (ch === "%" && hexDigits.has(this.buffer[i + 1]) && hexDigits.has(this.buffer[i + 2])) {
              ch = this.buffer[i += 3];
            } else
              break;
          }
          return yield* this.pushToIndex(i, false);
        }
      }
      *pushNewline() {
        const ch = this.buffer[this.pos];
        if (ch === "\n")
          return yield* this.pushCount(1);
        else if (ch === "\r" && this.charAt(1) === "\n")
          return yield* this.pushCount(2);
        else
          return 0;
      }
      *pushSpaces(allowTabs) {
        let i = this.pos - 1;
        let ch;
        do {
          ch = this.buffer[++i];
        } while (ch === " " || allowTabs && ch === "	");
        const n = i - this.pos;
        if (n > 0) {
          yield this.buffer.substr(this.pos, n);
          this.pos = i;
        }
        return n;
      }
      *pushUntil(test) {
        let i = this.pos;
        let ch = this.buffer[i];
        while (!test(ch))
          ch = this.buffer[++i];
        return yield* this.pushToIndex(i, false);
      }
    };
    exports.Lexer = Lexer;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/line-counter.js
var require_line_counter = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/line-counter.js"(exports) {
    "use strict";
    var LineCounter = class {
      constructor() {
        this.lineStarts = [];
        this.addNewLine = (offset) => this.lineStarts.push(offset);
        this.linePos = (offset) => {
          let low = 0;
          let high = this.lineStarts.length;
          while (low < high) {
            const mid = low + high >> 1;
            if (this.lineStarts[mid] < offset)
              low = mid + 1;
            else
              high = mid;
          }
          if (this.lineStarts[low] === offset)
            return { line: low + 1, col: 1 };
          if (low === 0)
            return { line: 0, col: offset };
          const start = this.lineStarts[low - 1];
          return { line: low, col: offset - start + 1 };
        };
      }
    };
    exports.LineCounter = LineCounter;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/parser.js
var require_parser = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/parse/parser.js"(exports) {
    "use strict";
    var node_process = __require("process");
    var cst = require_cst();
    var lexer = require_lexer();
    function includesToken(list2, type) {
      for (let i = 0; i < list2.length; ++i)
        if (list2[i].type === type)
          return true;
      return false;
    }
    function findNonEmptyIndex(list2) {
      for (let i = 0; i < list2.length; ++i) {
        switch (list2[i].type) {
          case "space":
          case "comment":
          case "newline":
            break;
          default:
            return i;
        }
      }
      return -1;
    }
    function isFlowToken(token) {
      switch (token?.type) {
        case "alias":
        case "scalar":
        case "single-quoted-scalar":
        case "double-quoted-scalar":
        case "flow-collection":
          return true;
        default:
          return false;
      }
    }
    function getPrevProps(parent) {
      switch (parent.type) {
        case "document":
          return parent.start;
        case "block-map": {
          const it = parent.items[parent.items.length - 1];
          return it.sep ?? it.start;
        }
        case "block-seq":
          return parent.items[parent.items.length - 1].start;
        /* istanbul ignore next should not happen */
        default:
          return [];
      }
    }
    function getFirstKeyStartProps(prev) {
      if (prev.length === 0)
        return [];
      let i = prev.length;
      loop: while (--i >= 0) {
        switch (prev[i].type) {
          case "doc-start":
          case "explicit-key-ind":
          case "map-value-ind":
          case "seq-item-ind":
          case "newline":
            break loop;
        }
      }
      while (prev[++i]?.type === "space") {
      }
      return prev.splice(i, prev.length);
    }
    function arrayPushArray(target, source) {
      if (source.length < 1e5)
        Array.prototype.push.apply(target, source);
      else
        for (let i = 0; i < source.length; ++i)
          target.push(source[i]);
    }
    function fixFlowSeqItems(fc) {
      if (fc.start.type === "flow-seq-start") {
        for (const it of fc.items) {
          if (it.sep && !it.value && !includesToken(it.start, "explicit-key-ind") && !includesToken(it.sep, "map-value-ind")) {
            if (it.key)
              it.value = it.key;
            delete it.key;
            if (isFlowToken(it.value)) {
              if (it.value.end)
                arrayPushArray(it.value.end, it.sep);
              else
                it.value.end = it.sep;
            } else
              arrayPushArray(it.start, it.sep);
            delete it.sep;
          }
        }
      }
    }
    var Parser2 = class {
      /**
       * @param onNewLine - If defined, called separately with the start position of
       *   each new line (in `parse()`, including the start of input).
       */
      constructor(onNewLine) {
        this.atNewLine = true;
        this.atScalar = false;
        this.indent = 0;
        this.offset = 0;
        this.onKeyLine = false;
        this.stack = [];
        this.source = "";
        this.type = "";
        this.lexer = new lexer.Lexer();
        this.onNewLine = onNewLine;
      }
      /**
       * Parse `source` as a YAML stream.
       * If `incomplete`, a part of the last line may be left as a buffer for the next call.
       *
       * Errors are not thrown, but yielded as `{ type: 'error', message }` tokens.
       *
       * @returns A generator of tokens representing each directive, document, and other structure.
       */
      *parse(source, incomplete = false) {
        if (this.onNewLine && this.offset === 0)
          this.onNewLine(0);
        for (const lexeme of this.lexer.lex(source, incomplete))
          yield* this.next(lexeme);
        if (!incomplete)
          yield* this.end();
      }
      /**
       * Advance the parser by the `source` of one lexical token.
       */
      *next(source) {
        this.source = source;
        if (node_process.env.LOG_TOKENS)
          console.log("|", cst.prettyToken(source));
        if (this.atScalar) {
          this.atScalar = false;
          yield* this.step();
          this.offset += source.length;
          return;
        }
        const type = cst.tokenType(source);
        if (!type) {
          const message = `Not a YAML token: ${source}`;
          yield* this.pop({ type: "error", offset: this.offset, message, source });
          this.offset += source.length;
        } else if (type === "scalar") {
          this.atNewLine = false;
          this.atScalar = true;
          this.type = "scalar";
        } else {
          this.type = type;
          yield* this.step();
          switch (type) {
            case "newline":
              this.atNewLine = true;
              this.indent = 0;
              if (this.onNewLine)
                this.onNewLine(this.offset + source.length);
              break;
            case "space":
              if (this.atNewLine && source[0] === " ")
                this.indent += source.length;
              break;
            case "explicit-key-ind":
            case "map-value-ind":
            case "seq-item-ind":
              if (this.atNewLine)
                this.indent += source.length;
              break;
            case "doc-mode":
            case "flow-error-end":
              return;
            default:
              this.atNewLine = false;
          }
          this.offset += source.length;
        }
      }
      /** Call at end of input to push out any remaining constructions */
      *end() {
        while (this.stack.length > 0)
          yield* this.pop();
      }
      get sourceToken() {
        const st = {
          type: this.type,
          offset: this.offset,
          indent: this.indent,
          source: this.source
        };
        return st;
      }
      *step() {
        const top = this.peek(1);
        if (this.type === "doc-end" && top?.type !== "doc-end") {
          while (this.stack.length > 0)
            yield* this.pop();
          this.stack.push({
            type: "doc-end",
            offset: this.offset,
            source: this.source
          });
          return;
        }
        if (!top)
          return yield* this.stream();
        switch (top.type) {
          case "document":
            return yield* this.document(top);
          case "alias":
          case "scalar":
          case "single-quoted-scalar":
          case "double-quoted-scalar":
            return yield* this.scalar(top);
          case "block-scalar":
            return yield* this.blockScalar(top);
          case "block-map":
            return yield* this.blockMap(top);
          case "block-seq":
            return yield* this.blockSequence(top);
          case "flow-collection":
            return yield* this.flowCollection(top);
          case "doc-end":
            return yield* this.documentEnd(top);
        }
        yield* this.pop();
      }
      peek(n) {
        return this.stack[this.stack.length - n];
      }
      *pop(error) {
        const token = error ?? this.stack.pop();
        if (!token) {
          const message = "Tried to pop an empty stack";
          yield { type: "error", offset: this.offset, source: "", message };
        } else if (this.stack.length === 0) {
          yield token;
        } else {
          const top = this.peek(1);
          if (token.type === "block-scalar") {
            token.indent = "indent" in top ? top.indent : 0;
          } else if (token.type === "flow-collection" && top.type === "document") {
            token.indent = 0;
          }
          if (token.type === "flow-collection")
            fixFlowSeqItems(token);
          switch (top.type) {
            case "document":
              top.value = token;
              break;
            case "block-scalar":
              top.props.push(token);
              break;
            case "block-map": {
              const it = top.items[top.items.length - 1];
              if (it.value) {
                top.items.push({ start: [], key: token, sep: [] });
                this.onKeyLine = true;
                return;
              } else if (it.sep) {
                it.value = token;
              } else {
                Object.assign(it, { key: token, sep: [] });
                this.onKeyLine = !it.explicitKey;
                return;
              }
              break;
            }
            case "block-seq": {
              const it = top.items[top.items.length - 1];
              if (it.value)
                top.items.push({ start: [], value: token });
              else
                it.value = token;
              break;
            }
            case "flow-collection": {
              const it = top.items[top.items.length - 1];
              if (!it || it.value)
                top.items.push({ start: [], key: token, sep: [] });
              else if (it.sep)
                it.value = token;
              else
                Object.assign(it, { key: token, sep: [] });
              return;
            }
            /* istanbul ignore next should not happen */
            default:
              yield* this.pop();
              yield* this.pop(token);
          }
          if ((top.type === "document" || top.type === "block-map" || top.type === "block-seq") && (token.type === "block-map" || token.type === "block-seq")) {
            const last = token.items[token.items.length - 1];
            if (last && !last.sep && !last.value && last.start.length > 0 && findNonEmptyIndex(last.start) === -1 && (token.indent === 0 || last.start.every((st) => st.type !== "comment" || st.indent < token.indent))) {
              if (top.type === "document")
                top.end = last.start;
              else
                top.items.push({ start: last.start });
              token.items.splice(-1, 1);
            }
          }
        }
      }
      *stream() {
        switch (this.type) {
          case "directive-line":
            yield { type: "directive", offset: this.offset, source: this.source };
            return;
          case "byte-order-mark":
          case "space":
          case "comment":
          case "newline":
            yield this.sourceToken;
            return;
          case "doc-mode":
          case "doc-start": {
            const doc = {
              type: "document",
              offset: this.offset,
              start: []
            };
            if (this.type === "doc-start")
              doc.start.push(this.sourceToken);
            this.stack.push(doc);
            return;
          }
        }
        yield {
          type: "error",
          offset: this.offset,
          message: `Unexpected ${this.type} token in YAML stream`,
          source: this.source
        };
      }
      *document(doc) {
        if (doc.value)
          return yield* this.lineEnd(doc);
        switch (this.type) {
          case "doc-start": {
            if (findNonEmptyIndex(doc.start) !== -1) {
              yield* this.pop();
              yield* this.step();
            } else
              doc.start.push(this.sourceToken);
            return;
          }
          case "anchor":
          case "tag":
          case "space":
          case "comment":
          case "newline":
            doc.start.push(this.sourceToken);
            return;
        }
        const bv = this.startBlockValue(doc);
        if (bv)
          this.stack.push(bv);
        else {
          yield {
            type: "error",
            offset: this.offset,
            message: `Unexpected ${this.type} token in YAML document`,
            source: this.source
          };
        }
      }
      *scalar(scalar) {
        if (this.type === "map-value-ind") {
          const prev = getPrevProps(this.peek(2));
          const start = getFirstKeyStartProps(prev);
          let sep;
          if (scalar.end) {
            sep = scalar.end;
            sep.push(this.sourceToken);
            delete scalar.end;
          } else
            sep = [this.sourceToken];
          const map = {
            type: "block-map",
            offset: scalar.offset,
            indent: scalar.indent,
            items: [{ start, key: scalar, sep }]
          };
          this.onKeyLine = true;
          this.stack[this.stack.length - 1] = map;
        } else
          yield* this.lineEnd(scalar);
      }
      *blockScalar(scalar) {
        switch (this.type) {
          case "space":
          case "comment":
          case "newline":
            scalar.props.push(this.sourceToken);
            return;
          case "scalar":
            scalar.source = this.source;
            this.atNewLine = true;
            this.indent = 0;
            if (this.onNewLine) {
              let nl = this.source.indexOf("\n") + 1;
              while (nl !== 0) {
                this.onNewLine(this.offset + nl);
                nl = this.source.indexOf("\n", nl) + 1;
              }
            }
            yield* this.pop();
            break;
          /* istanbul ignore next should not happen */
          default:
            yield* this.pop();
            yield* this.step();
        }
      }
      *blockMap(map) {
        const it = map.items[map.items.length - 1];
        switch (this.type) {
          case "newline":
            this.onKeyLine = false;
            if (it.value) {
              const end = "end" in it.value ? it.value.end : void 0;
              const last = Array.isArray(end) ? end[end.length - 1] : void 0;
              if (last?.type === "comment")
                end?.push(this.sourceToken);
              else
                map.items.push({ start: [this.sourceToken] });
            } else if (it.sep) {
              it.sep.push(this.sourceToken);
            } else {
              it.start.push(this.sourceToken);
            }
            return;
          case "space":
          case "comment":
            if (it.value) {
              map.items.push({ start: [this.sourceToken] });
            } else if (it.sep) {
              it.sep.push(this.sourceToken);
            } else {
              if (this.atIndentedComment(it.start, map.indent)) {
                const prev = map.items[map.items.length - 2];
                const end = prev?.value?.end;
                if (Array.isArray(end)) {
                  arrayPushArray(end, it.start);
                  end.push(this.sourceToken);
                  map.items.pop();
                  return;
                }
              }
              it.start.push(this.sourceToken);
            }
            return;
        }
        if (this.indent >= map.indent) {
          const atMapIndent = !this.onKeyLine && this.indent === map.indent;
          const atNextItem = atMapIndent && (it.sep || it.explicitKey) && this.type !== "seq-item-ind";
          let start = [];
          if (atNextItem && it.sep && !it.value) {
            const nl = [];
            for (let i = 0; i < it.sep.length; ++i) {
              const st = it.sep[i];
              switch (st.type) {
                case "newline":
                  nl.push(i);
                  break;
                case "space":
                  break;
                case "comment":
                  if (st.indent > map.indent)
                    nl.length = 0;
                  break;
                default:
                  nl.length = 0;
              }
            }
            if (nl.length >= 2)
              start = it.sep.splice(nl[1]);
          }
          switch (this.type) {
            case "anchor":
            case "tag":
              if (atNextItem || it.value) {
                start.push(this.sourceToken);
                map.items.push({ start });
                this.onKeyLine = true;
              } else if (it.sep) {
                it.sep.push(this.sourceToken);
              } else {
                it.start.push(this.sourceToken);
              }
              return;
            case "explicit-key-ind":
              if (!it.sep && !it.explicitKey) {
                it.start.push(this.sourceToken);
                it.explicitKey = true;
              } else if (atNextItem || it.value) {
                start.push(this.sourceToken);
                map.items.push({ start, explicitKey: true });
              } else {
                this.stack.push({
                  type: "block-map",
                  offset: this.offset,
                  indent: this.indent,
                  items: [{ start: [this.sourceToken], explicitKey: true }]
                });
              }
              this.onKeyLine = true;
              return;
            case "map-value-ind":
              if (it.explicitKey) {
                if (!it.sep) {
                  if (includesToken(it.start, "newline")) {
                    Object.assign(it, { key: null, sep: [this.sourceToken] });
                  } else {
                    const start2 = getFirstKeyStartProps(it.start);
                    this.stack.push({
                      type: "block-map",
                      offset: this.offset,
                      indent: this.indent,
                      items: [{ start: start2, key: null, sep: [this.sourceToken] }]
                    });
                  }
                } else if (it.value) {
                  map.items.push({ start: [], key: null, sep: [this.sourceToken] });
                } else if (includesToken(it.sep, "map-value-ind")) {
                  this.stack.push({
                    type: "block-map",
                    offset: this.offset,
                    indent: this.indent,
                    items: [{ start, key: null, sep: [this.sourceToken] }]
                  });
                } else if (isFlowToken(it.key) && !includesToken(it.sep, "newline")) {
                  const start2 = getFirstKeyStartProps(it.start);
                  const key = it.key;
                  const sep = it.sep;
                  sep.push(this.sourceToken);
                  delete it.key;
                  delete it.sep;
                  this.stack.push({
                    type: "block-map",
                    offset: this.offset,
                    indent: this.indent,
                    items: [{ start: start2, key, sep }]
                  });
                } else if (start.length > 0) {
                  it.sep = it.sep.concat(start, this.sourceToken);
                } else {
                  it.sep.push(this.sourceToken);
                }
              } else {
                if (!it.sep) {
                  Object.assign(it, { key: null, sep: [this.sourceToken] });
                } else if (it.value || atNextItem) {
                  map.items.push({ start, key: null, sep: [this.sourceToken] });
                } else if (includesToken(it.sep, "map-value-ind")) {
                  this.stack.push({
                    type: "block-map",
                    offset: this.offset,
                    indent: this.indent,
                    items: [{ start: [], key: null, sep: [this.sourceToken] }]
                  });
                } else {
                  it.sep.push(this.sourceToken);
                }
              }
              this.onKeyLine = true;
              return;
            case "alias":
            case "scalar":
            case "single-quoted-scalar":
            case "double-quoted-scalar": {
              const fs = this.flowScalar(this.type);
              if (atNextItem || it.value) {
                map.items.push({ start, key: fs, sep: [] });
                this.onKeyLine = true;
              } else if (it.sep) {
                this.stack.push(fs);
              } else {
                Object.assign(it, { key: fs, sep: [] });
                this.onKeyLine = true;
              }
              return;
            }
            default: {
              const bv = this.startBlockValue(map);
              if (bv) {
                if (bv.type === "block-seq") {
                  if (!it.explicitKey && it.sep && !includesToken(it.sep, "newline")) {
                    yield* this.pop({
                      type: "error",
                      offset: this.offset,
                      message: "Unexpected block-seq-ind on same line with key",
                      source: this.source
                    });
                    return;
                  }
                } else if (atMapIndent) {
                  map.items.push({ start });
                }
                this.stack.push(bv);
                return;
              }
            }
          }
        }
        yield* this.pop();
        yield* this.step();
      }
      *blockSequence(seq) {
        const it = seq.items[seq.items.length - 1];
        switch (this.type) {
          case "newline":
            if (it.value) {
              const end = "end" in it.value ? it.value.end : void 0;
              const last = Array.isArray(end) ? end[end.length - 1] : void 0;
              if (last?.type === "comment")
                end?.push(this.sourceToken);
              else
                seq.items.push({ start: [this.sourceToken] });
            } else
              it.start.push(this.sourceToken);
            return;
          case "space":
          case "comment":
            if (it.value)
              seq.items.push({ start: [this.sourceToken] });
            else {
              if (this.atIndentedComment(it.start, seq.indent)) {
                const prev = seq.items[seq.items.length - 2];
                const end = prev?.value?.end;
                if (Array.isArray(end)) {
                  arrayPushArray(end, it.start);
                  end.push(this.sourceToken);
                  seq.items.pop();
                  return;
                }
              }
              it.start.push(this.sourceToken);
            }
            return;
          case "anchor":
          case "tag":
            if (it.value || this.indent <= seq.indent)
              break;
            it.start.push(this.sourceToken);
            return;
          case "seq-item-ind":
            if (this.indent !== seq.indent)
              break;
            if (it.value || includesToken(it.start, "seq-item-ind"))
              seq.items.push({ start: [this.sourceToken] });
            else
              it.start.push(this.sourceToken);
            return;
        }
        if (this.indent > seq.indent) {
          const bv = this.startBlockValue(seq);
          if (bv) {
            this.stack.push(bv);
            return;
          }
        }
        yield* this.pop();
        yield* this.step();
      }
      *flowCollection(fc) {
        const it = fc.items[fc.items.length - 1];
        if (this.type === "flow-error-end") {
          let top;
          do {
            yield* this.pop();
            top = this.peek(1);
          } while (top?.type === "flow-collection");
        } else if (fc.end.length === 0) {
          switch (this.type) {
            case "comma":
            case "explicit-key-ind":
              if (!it || it.sep)
                fc.items.push({ start: [this.sourceToken] });
              else
                it.start.push(this.sourceToken);
              return;
            case "map-value-ind":
              if (!it || it.value)
                fc.items.push({ start: [], key: null, sep: [this.sourceToken] });
              else if (it.sep)
                it.sep.push(this.sourceToken);
              else
                Object.assign(it, { key: null, sep: [this.sourceToken] });
              return;
            case "space":
            case "comment":
            case "newline":
            case "anchor":
            case "tag":
              if (!it || it.value)
                fc.items.push({ start: [this.sourceToken] });
              else if (it.sep)
                it.sep.push(this.sourceToken);
              else
                it.start.push(this.sourceToken);
              return;
            case "alias":
            case "scalar":
            case "single-quoted-scalar":
            case "double-quoted-scalar": {
              const fs = this.flowScalar(this.type);
              if (!it || it.value)
                fc.items.push({ start: [], key: fs, sep: [] });
              else if (it.sep)
                this.stack.push(fs);
              else
                Object.assign(it, { key: fs, sep: [] });
              return;
            }
            case "flow-map-end":
            case "flow-seq-end":
              fc.end.push(this.sourceToken);
              return;
          }
          const bv = this.startBlockValue(fc);
          if (bv)
            this.stack.push(bv);
          else {
            yield* this.pop();
            yield* this.step();
          }
        } else {
          const parent = this.peek(2);
          if (parent.type === "block-map" && (this.type === "map-value-ind" && parent.indent === fc.indent || this.type === "newline" && !parent.items[parent.items.length - 1].sep)) {
            yield* this.pop();
            yield* this.step();
          } else if (this.type === "map-value-ind" && parent.type !== "flow-collection") {
            const prev = getPrevProps(parent);
            const start = getFirstKeyStartProps(prev);
            fixFlowSeqItems(fc);
            const sep = fc.end.splice(1, fc.end.length);
            sep.push(this.sourceToken);
            const map = {
              type: "block-map",
              offset: fc.offset,
              indent: fc.indent,
              items: [{ start, key: fc, sep }]
            };
            this.onKeyLine = true;
            this.stack[this.stack.length - 1] = map;
          } else {
            yield* this.lineEnd(fc);
          }
        }
      }
      flowScalar(type) {
        if (this.onNewLine) {
          let nl = this.source.indexOf("\n") + 1;
          while (nl !== 0) {
            this.onNewLine(this.offset + nl);
            nl = this.source.indexOf("\n", nl) + 1;
          }
        }
        return {
          type,
          offset: this.offset,
          indent: this.indent,
          source: this.source
        };
      }
      startBlockValue(parent) {
        switch (this.type) {
          case "alias":
          case "scalar":
          case "single-quoted-scalar":
          case "double-quoted-scalar":
            return this.flowScalar(this.type);
          case "block-scalar-header":
            return {
              type: "block-scalar",
              offset: this.offset,
              indent: this.indent,
              props: [this.sourceToken],
              source: ""
            };
          case "flow-map-start":
          case "flow-seq-start":
            return {
              type: "flow-collection",
              offset: this.offset,
              indent: this.indent,
              start: this.sourceToken,
              items: [],
              end: []
            };
          case "seq-item-ind":
            return {
              type: "block-seq",
              offset: this.offset,
              indent: this.indent,
              items: [{ start: [this.sourceToken] }]
            };
          case "explicit-key-ind": {
            this.onKeyLine = true;
            const prev = getPrevProps(parent);
            const start = getFirstKeyStartProps(prev);
            start.push(this.sourceToken);
            return {
              type: "block-map",
              offset: this.offset,
              indent: this.indent,
              items: [{ start, explicitKey: true }]
            };
          }
          case "map-value-ind": {
            this.onKeyLine = true;
            const prev = getPrevProps(parent);
            const start = getFirstKeyStartProps(prev);
            return {
              type: "block-map",
              offset: this.offset,
              indent: this.indent,
              items: [{ start, key: null, sep: [this.sourceToken] }]
            };
          }
        }
        return null;
      }
      atIndentedComment(start, indent) {
        if (this.type !== "comment")
          return false;
        if (this.indent <= indent)
          return false;
        return start.every((st) => st.type === "newline" || st.type === "space");
      }
      *documentEnd(docEnd) {
        if (this.type !== "doc-mode") {
          if (docEnd.end)
            docEnd.end.push(this.sourceToken);
          else
            docEnd.end = [this.sourceToken];
          if (this.type === "newline")
            yield* this.pop();
        }
      }
      *lineEnd(token) {
        switch (this.type) {
          case "comma":
          case "doc-start":
          case "doc-end":
          case "flow-seq-end":
          case "flow-map-end":
          case "map-value-ind":
            yield* this.pop();
            yield* this.step();
            break;
          case "newline":
            this.onKeyLine = false;
          // fallthrough
          case "space":
          case "comment":
          default:
            if (token.end)
              token.end.push(this.sourceToken);
            else
              token.end = [this.sourceToken];
            if (this.type === "newline")
              yield* this.pop();
        }
      }
    };
    exports.Parser = Parser2;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/public-api.js
var require_public_api = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/public-api.js"(exports) {
    "use strict";
    var composer = require_composer();
    var Document = require_Document();
    var errors = require_errors();
    var log = require_log();
    var identity = require_identity();
    var lineCounter = require_line_counter();
    var parser = require_parser();
    function parseOptions(options) {
      const prettyErrors = options.prettyErrors !== false;
      const lineCounter$1 = options.lineCounter || prettyErrors && new lineCounter.LineCounter() || null;
      return { lineCounter: lineCounter$1, prettyErrors };
    }
    function parseAllDocuments(source, options = {}) {
      const { lineCounter: lineCounter2, prettyErrors } = parseOptions(options);
      const parser$1 = new parser.Parser(lineCounter2?.addNewLine);
      const composer$1 = new composer.Composer(options);
      const docs = Array.from(composer$1.compose(parser$1.parse(source)));
      if (prettyErrors && lineCounter2)
        for (const doc of docs) {
          doc.errors.forEach(errors.prettifyError(source, lineCounter2));
          doc.warnings.forEach(errors.prettifyError(source, lineCounter2));
        }
      if (docs.length > 0)
        return docs;
      return Object.assign([], { empty: true }, composer$1.streamInfo());
    }
    function parseDocument2(source, options = {}) {
      const { lineCounter: lineCounter2, prettyErrors } = parseOptions(options);
      const parser$1 = new parser.Parser(lineCounter2?.addNewLine);
      const composer$1 = new composer.Composer(options);
      let doc = null;
      for (const _doc of composer$1.compose(parser$1.parse(source), true, source.length)) {
        if (!doc)
          doc = _doc;
        else if (doc.options.logLevel !== "silent") {
          doc.errors.push(new errors.YAMLParseError(_doc.range.slice(0, 2), "MULTIPLE_DOCS", "Source contains multiple documents; please use YAML.parseAllDocuments()"));
          break;
        }
      }
      if (prettyErrors && lineCounter2) {
        doc.errors.forEach(errors.prettifyError(source, lineCounter2));
        doc.warnings.forEach(errors.prettifyError(source, lineCounter2));
      }
      return doc;
    }
    function parse(src, reviver, options) {
      let _reviver = void 0;
      if (typeof reviver === "function") {
        _reviver = reviver;
      } else if (options === void 0 && reviver && typeof reviver === "object") {
        options = reviver;
      }
      const doc = parseDocument2(src, options);
      if (!doc)
        return null;
      doc.warnings.forEach((warning) => log.warn(doc.options.logLevel, warning));
      if (doc.errors.length > 0) {
        if (doc.options.logLevel !== "silent")
          throw doc.errors[0];
        else
          doc.errors = [];
      }
      return doc.toJS(Object.assign({ reviver: _reviver }, options));
    }
    function stringify(value, replacer, options) {
      let _replacer = null;
      if (typeof replacer === "function" || Array.isArray(replacer)) {
        _replacer = replacer;
      } else if (options === void 0 && replacer) {
        options = replacer;
      }
      if (typeof options === "string")
        options = options.length;
      if (typeof options === "number") {
        const indent = Math.round(options);
        options = indent < 1 ? void 0 : indent > 8 ? { indent: 8 } : { indent };
      }
      if (value === void 0) {
        const { keepUndefined } = options ?? replacer ?? {};
        if (!keepUndefined)
          return void 0;
      }
      if (identity.isDocument(value) && !_replacer)
        return value.toString(options);
      return new Document.Document(value, _replacer, options).toString(options);
    }
    exports.parse = parse;
    exports.parseAllDocuments = parseAllDocuments;
    exports.parseDocument = parseDocument2;
    exports.stringify = stringify;
  }
});

// node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/index.js
var require_dist = __commonJS({
  "node_modules/.pnpm/yaml@2.9.1/node_modules/yaml/dist/index.js"(exports) {
    "use strict";
    var composer = require_composer();
    var Document = require_Document();
    var Schema = require_Schema();
    var errors = require_errors();
    var Alias = require_Alias();
    var identity = require_identity();
    var Pair = require_Pair();
    var Scalar = require_Scalar();
    var YAMLMap = require_YAMLMap();
    var YAMLSeq = require_YAMLSeq();
    var cst = require_cst();
    var lexer = require_lexer();
    var lineCounter = require_line_counter();
    var parser = require_parser();
    var publicApi = require_public_api();
    var visit = require_visit();
    exports.Composer = composer.Composer;
    exports.Document = Document.Document;
    exports.Schema = Schema.Schema;
    exports.YAMLError = errors.YAMLError;
    exports.YAMLParseError = errors.YAMLParseError;
    exports.YAMLWarning = errors.YAMLWarning;
    exports.Alias = Alias.Alias;
    exports.isAlias = identity.isAlias;
    exports.isCollection = identity.isCollection;
    exports.isDocument = identity.isDocument;
    exports.isMap = identity.isMap;
    exports.isNode = identity.isNode;
    exports.isPair = identity.isPair;
    exports.isScalar = identity.isScalar;
    exports.isSeq = identity.isSeq;
    exports.Pair = Pair.Pair;
    exports.Scalar = Scalar.Scalar;
    exports.YAMLMap = YAMLMap.YAMLMap;
    exports.YAMLSeq = YAMLSeq.YAMLSeq;
    exports.CST = cst;
    exports.Lexer = lexer.Lexer;
    exports.LineCounter = lineCounter.LineCounter;
    exports.Parser = parser.Parser;
    exports.parse = publicApi.parse;
    exports.parseAllDocuments = publicApi.parseAllDocuments;
    exports.parseDocument = publicApi.parseDocument;
    exports.stringify = publicApi.stringify;
    exports.visit = visit.visit;
    exports.visitAsync = visit.visitAsync;
  }
});

// src/main.ts
import { existsSync as existsSync5, readFileSync as readFileSync5 } from "node:fs";
import { join as join6, relative, resolve } from "node:path";

// src/check.ts
var import_yaml = __toESM(require_dist(), 1);
import { existsSync as existsSync3, readFileSync as readFileSync3 } from "node:fs";
import { basename, join as join3 } from "node:path";

// src/schema.ts
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
var CONFIG_FILE = ".living-spec.json";
var DEFAULT_LAYOUT = {
  tables: "docs/rdra",
  requirements: "docs/requirements",
  examples: "docs/examples",
  output: ".cache/living-spec/index.html",
  hook: true
};
var LAYOUT = { ...DEFAULT_LAYOUT };
function configureLayout(root) {
  Object.assign(LAYOUT, DEFAULT_LAYOUT);
  const path = join(root, CONFIG_FILE);
  if (!existsSync(path)) return LAYOUT;
  const data = JSON.parse(readFileSync(path, "utf8"));
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    throw new Error(`${CONFIG_FILE} \u306F\u30AA\u30D6\u30B8\u30A7\u30AF\u30C8\u3067\u66F8\u304F`);
  }
  for (const [key, value] of Object.entries(data)) {
    if (!Object.hasOwn(DEFAULT_LAYOUT, key)) throw new Error(`${CONFIG_FILE} \u306E\u672A\u77E5\u306E\u30AD\u30FC\u300E${key}\u300F`);
    const want = typeof DEFAULT_LAYOUT[key];
    if (typeof value !== want || value === "") throw new Error(`${CONFIG_FILE} \u306E\u300E${key}\u300F\u306F${want === "boolean" ? "\u771F\u507D\u5024" : "\u7A7A\u3067\u306A\u3044\u6587\u5B57\u5217"}\u3067\u66F8\u304F`);
    LAYOUT[key] = typeof value === "string" ? value.replace(/\/+$/, "") : value;
  }
  return LAYOUT;
}
var HYPOTHESIS = "\u4EEE\u8AAC";
var TABLES = [
  {
    id: "actor",
    get file() {
      return `${LAYOUT.tables}/actor.yaml`;
    },
    kind: "\u30A2\u30AF\u30BF\u30FC",
    nameKey: "\u30A2\u30AF\u30BF\u30FC",
    keys: { \u30A2\u30AF\u30BF\u30FC: "string", \u5F79\u5272: "string", \u793E\u5185\u5916: "string", [HYPOTHESIS]: "list" },
    splitKeys: [],
    emptyOkKeys: []
  },
  {
    id: "external-system",
    get file() {
      return `${LAYOUT.tables}/external-system.yaml`;
    },
    kind: "\u5916\u90E8\u30B7\u30B9\u30C6\u30E0",
    nameKey: "\u5916\u90E8\u30B7\u30B9\u30C6\u30E0",
    keys: { \u5916\u90E8\u30B7\u30B9\u30C6\u30E0: "string", \u5F79\u5272: "string", [HYPOTHESIS]: "list" },
    splitKeys: [],
    emptyOkKeys: []
  },
  {
    id: "information",
    get file() {
      return `${LAYOUT.tables}/information.yaml`;
    },
    kind: "\u60C5\u5831",
    nameKey: "\u60C5\u5831",
    keys: {
      \u60C5\u5831: "string",
      \u5C5E\u6027: "string",
      \u95A2\u9023\u60C5\u5831: "string",
      \u72B6\u614B\u30E2\u30C7\u30EB: "string",
      \u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3: "string",
      \u8AAC\u660E: "string",
      [HYPOTHESIS]: "list"
    },
    splitKeys: ["\u5C5E\u6027", "\u95A2\u9023\u60C5\u5831", "\u72B6\u614B\u30E2\u30C7\u30EB", "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3"],
    emptyOkKeys: []
  },
  {
    id: "state",
    get file() {
      return `${LAYOUT.tables}/state.yaml`;
    },
    kind: "\u72B6\u614B",
    nameKey: "\u72B6\u614B\u30E2\u30C7\u30EB",
    keys: {
      \u72B6\u614B\u30E2\u30C7\u30EB: "string",
      \u72B6\u614B: "string",
      \u9077\u79FBUC: "string",
      \u9077\u79FB\u5148\u72B6\u614B: "string",
      "\u72B6\u614B\u30E2\u30C7\u30EB\u30FB\u72B6\u614B\u306E\u8AAC\u660E": "string",
      [HYPOTHESIS]: "list"
    },
    splitKeys: [],
    // 初期遷移は 状態 を、終端の状態は 遷移UC・遷移先状態 を省略または空にする
    emptyOkKeys: ["\u72B6\u614B", "\u9077\u79FBUC", "\u9077\u79FB\u5148\u72B6\u614B"]
  },
  {
    id: "use-case",
    get file() {
      return `${LAYOUT.tables}/use-case.yaml`;
    },
    kind: "UC",
    nameKey: "UC",
    keys: {
      UC: "string",
      \u30A2\u30AF\u30BF\u30FC: "list",
      \u5916\u90E8\u30B7\u30B9\u30C6\u30E0: "list",
      \u60C5\u5831: "list",
      \u6761\u4EF6: "list",
      \u8AAC\u660E: "string",
      [HYPOTHESIS]: "list"
    },
    splitKeys: [],
    emptyOkKeys: []
  },
  {
    id: "condition",
    get file() {
      return `${LAYOUT.tables}/condition.yaml`;
    },
    kind: "\u6761\u4EF6",
    nameKey: "\u6761\u4EF6",
    keys: {
      \u6761\u4EF6: "string",
      \u6761\u4EF6\u306E\u8AAC\u660E: "string",
      \u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3: "string",
      \u72B6\u614B\u30E2\u30C7\u30EB: "string",
      [HYPOTHESIS]: "list"
    },
    splitKeys: ["\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3", "\u72B6\u614B\u30E2\u30C7\u30EB"],
    emptyOkKeys: []
  },
  {
    id: "variation",
    get file() {
      return `${LAYOUT.tables}/variation.yaml`;
    },
    kind: "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3",
    nameKey: "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3",
    keys: { \u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3: "string", \u5024: "string", \u8AAC\u660E: "string", [HYPOTHESIS]: "list" },
    splitKeys: ["\u5024"],
    emptyOkKeys: []
  },
  {
    id: "architecture-characteristic",
    get file() {
      return `${LAYOUT.tables}/architecture-characteristic.yaml`;
    },
    kind: "\u30A2\u30FC\u30AD\u30C6\u30AF\u30C1\u30E3\u7279\u6027",
    nameKey: "\u30A2\u30FC\u30AD\u30C6\u30AF\u30C1\u30E3\u7279\u6027",
    keys: {
      \u30A2\u30FC\u30AD\u30C6\u30AF\u30C1\u30E3\u7279\u6027: "string",
      \u5206\u985E: "string",
      \u8AAC\u660E: "string",
      \u691C\u8A3C\u65B9\u6CD5: "string",
      [HYPOTHESIS]: "list"
    },
    splitKeys: [],
    emptyOkKeys: []
  }
];
function tableById(id) {
  const t = TABLES.find((x) => x.id === id);
  if (!t) throw new Error(`\u672A\u77E5\u306E\u8868: ${id}`);
  return t;
}
var REQUIREMENT_KINDS = [
  "\u30A2\u30AF\u30BF\u30FC",
  "\u5916\u90E8\u30B7\u30B9\u30C6\u30E0",
  "\u60C5\u5831",
  "\u72B6\u614B\u30E2\u30C7\u30EB",
  "\u72B6\u614B",
  "UC",
  "\u6761\u4EF6",
  "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3",
  "\u30A2\u30FC\u30AD\u30C6\u30AF\u30C1\u30E3\u7279\u6027"
];
var REQUIREMENT_TITLE_LABEL = "\u8981\u6C42\u7968";
var REQUIREMENT_SPEC_HEADING = "\u4ED5\u69D8";
var REQUIREMENT_RDRA_FIELD = "RDRA";
var REQUIREMENT_REASON_HEADING = "\u7406\u7531";
var REQUIREMENT_REASON_FIELD = "\u7406\u7531";
var REQUIREMENT_NO_REFERENCE = "\u306A\u3057";
var REQUIREMENT_STATE_SEP = "/";
var EXAMPLE_LIMIT = 3;

// src/trace.ts
import { existsSync as existsSync2, readdirSync, readFileSync as readFileSync2 } from "node:fs";
import { join as join2 } from "node:path";

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/AstNode.js
var AstNode = class {
  ruleType;
  // biome-ignore lint/suspicious/noExplicitAny: keys and values are heterogeneous AST entries
  subItems = /* @__PURE__ */ new Map();
  constructor(ruleType) {
    this.ruleType = ruleType;
  }
  // biome-ignore lint/suspicious/noExplicitAny: keys and values are heterogeneous AST entries
  add(type, obj) {
    let items = this.subItems.get(type);
    if (items === void 0) {
      items = [];
      this.subItems.set(type, items);
    }
    items.push(obj);
  }
  getSingle(ruleType) {
    return (this.subItems.get(ruleType) || [])[0];
  }
  getItems(ruleType) {
    return this.subItems.get(ruleType) || [];
  }
  getToken(tokenType) {
    return (this.subItems.get(tokenType) || [])[0];
  }
  getTokens(tokenType) {
    return this.subItems.get(tokenType) || [];
  }
};

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/Errors.js
var GherkinException = class extends Error {
  errors;
  location;
  constructor(message) {
    super(message);
    const actualProto = new.target.prototype;
    if (Object.setPrototypeOf) {
      Object.setPrototypeOf(this, actualProto);
    } else {
      this.__proto__ = actualProto;
    }
  }
  static _create(message, location) {
    const column = location != null ? location.column || 0 : -1;
    const line = location != null ? location.line || 0 : -1;
    const m = `(${line}:${column}): ${message}`;
    const err = new this(m);
    err.location = location;
    return err;
  }
};
var ParserException = class _ParserException extends GherkinException {
  static create(message, line, column) {
    const err = new _ParserException(`(${line}:${column}): ${message}`);
    err.location = { line, column };
    return err;
  }
};
var CompositeParserException = class _CompositeParserException extends GherkinException {
  static create(errors) {
    const message = `Parser errors:
${errors.map((e) => e.message).join("\n")}`;
    const err = new _CompositeParserException(message);
    err.errors = errors;
    return err;
  }
};
var AstBuilderException = class _AstBuilderException extends GherkinException {
  static create(message, location) {
    return _AstBuilderException._create(message, location);
  }
};
var NoSuchLanguageException = class _NoSuchLanguageException extends GherkinException {
  static create(language, location) {
    const message = `Language not supported: ${language}`;
    return _NoSuchLanguageException._create(message, location);
  }
};

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/TokenExceptions.js
var UnexpectedTokenException = class _UnexpectedTokenException extends GherkinException {
  static create(token, expectedTokenTypes) {
    const message = `expected: ${expectedTokenTypes.join(", ")}, got '${token.getTokenValue().trim()}'`;
    const location = tokenLocation(token);
    return _UnexpectedTokenException._create(message, location);
  }
};
var UnexpectedEOFException = class _UnexpectedEOFException extends GherkinException {
  static create(token, expectedTokenTypes) {
    const message = `unexpected end of file, expected: ${expectedTokenTypes.join(", ")}`;
    const location = tokenLocation(token);
    return _UnexpectedEOFException._create(message, location);
  }
};
function tokenLocation(token) {
  return token.location?.line && token.line && token.line.indent !== void 0 ? {
    line: token.location.line,
    column: token.line.indent + 1
  } : token.location;
}

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/TokenScanner.js
var TokenScanner = class {
  makeToken;
  lineNumber = 0;
  lines;
  constructor(source, makeToken) {
    this.makeToken = makeToken;
    this.lines = source.split(/\r?\n/);
    if (this.lines.length > 0 && this.lines[this.lines.length - 1].trim() === "") {
      this.lines.pop();
    }
  }
  read() {
    const line = this.lines[this.lineNumber++];
    const location = {
      line: this.lineNumber
    };
    return this.makeToken(line, location);
  }
};

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/countSymbols.js
var regexAstralSymbols = /[\uD800-\uDBFF][\uDC00-\uDFFF]/g;
function countSymbols(s) {
  return s.replace(regexAstralSymbols, "_").length;
}

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/GherkinLine.js
var GherkinLine = class {
  lineText;
  lineNumber;
  trimmedLineText;
  isEmpty;
  indent;
  column;
  text;
  constructor(lineText, lineNumber) {
    this.lineText = lineText;
    this.lineNumber = lineNumber;
    this.trimmedLineText = lineText.replace(/^\s+/g, "");
    this.isEmpty = this.trimmedLineText.length === 0;
    this.indent = countSymbols(lineText) - countSymbols(this.trimmedLineText);
  }
  startsWith(prefix) {
    return this.trimmedLineText.indexOf(prefix) === 0;
  }
  startsWithTitleKeyword(keyword) {
    return this.startsWith(`${keyword}:`);
  }
  match(regexp) {
    return this.trimmedLineText.match(regexp);
  }
  getLineText(indentToRemove) {
    if (indentToRemove < 0 || indentToRemove > this.indent) {
      return this.trimmedLineText;
    } else {
      return this.lineText.substring(indentToRemove);
    }
  }
  getRestTrimmed(length) {
    return this.trimmedLineText.substring(length).trim();
  }
  getTableCells() {
    const cells = [];
    let col = 0;
    let startCol = col + 1;
    let cell = "";
    let firstCell = true;
    while (col < this.trimmedLineText.length) {
      let chr = this.trimmedLineText[col];
      col++;
      if (chr === "|") {
        if (firstCell) {
          firstCell = false;
        } else {
          const trimmedLeft = cell.replace(/^[ \t\v\f\r\u0085\u00A0]*/g, "");
          const trimmed = trimmedLeft.replace(/[ \t\v\f\r\u0085\u00A0]*$/g, "");
          const cellIndent = cell.length - trimmedLeft.length;
          const span = {
            column: this.indent + startCol + cellIndent,
            text: trimmed
          };
          cells.push(span);
        }
        cell = "";
        startCol = col + 1;
      } else if (chr === "\\") {
        chr = this.trimmedLineText[col];
        col += 1;
        if (chr === "n") {
          cell += "\n";
        } else {
          if (chr !== "|" && chr !== "\\") {
            cell += "\\";
          }
          cell += chr;
        }
      } else {
        cell += chr;
      }
    }
    return cells;
  }
};

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/Parser.js
var Token = class {
  line;
  location;
  isEof;
  matchedText;
  matchedType;
  matchedItems;
  matchedKeyword;
  matchedIndent;
  matchedGherkinDialect;
  matchedKeywordType;
  constructor(line, location) {
    this.line = line;
    this.location = location;
    this.isEof = !line;
  }
  getTokenValue() {
    return this.isEof ? "EOF" : this.line.getLineText(-1);
  }
};
var TokenType;
(function(TokenType2) {
  TokenType2[TokenType2["None"] = 0] = "None";
  TokenType2[TokenType2["EOF"] = 1] = "EOF";
  TokenType2[TokenType2["Empty"] = 2] = "Empty";
  TokenType2[TokenType2["Comment"] = 3] = "Comment";
  TokenType2[TokenType2["TagLine"] = 4] = "TagLine";
  TokenType2[TokenType2["FeatureLine"] = 5] = "FeatureLine";
  TokenType2[TokenType2["RuleLine"] = 6] = "RuleLine";
  TokenType2[TokenType2["BackgroundLine"] = 7] = "BackgroundLine";
  TokenType2[TokenType2["ScenarioLine"] = 8] = "ScenarioLine";
  TokenType2[TokenType2["ExamplesLine"] = 9] = "ExamplesLine";
  TokenType2[TokenType2["StepLine"] = 10] = "StepLine";
  TokenType2[TokenType2["DocStringSeparator"] = 11] = "DocStringSeparator";
  TokenType2[TokenType2["TableRow"] = 12] = "TableRow";
  TokenType2[TokenType2["Language"] = 13] = "Language";
  TokenType2[TokenType2["Other"] = 14] = "Other";
})(TokenType || (TokenType = {}));
var RuleType;
(function(RuleType2) {
  RuleType2[RuleType2["None"] = 0] = "None";
  RuleType2[RuleType2["_EOF"] = 1] = "_EOF";
  RuleType2[RuleType2["_Empty"] = 2] = "_Empty";
  RuleType2[RuleType2["_Comment"] = 3] = "_Comment";
  RuleType2[RuleType2["_TagLine"] = 4] = "_TagLine";
  RuleType2[RuleType2["_FeatureLine"] = 5] = "_FeatureLine";
  RuleType2[RuleType2["_RuleLine"] = 6] = "_RuleLine";
  RuleType2[RuleType2["_BackgroundLine"] = 7] = "_BackgroundLine";
  RuleType2[RuleType2["_ScenarioLine"] = 8] = "_ScenarioLine";
  RuleType2[RuleType2["_ExamplesLine"] = 9] = "_ExamplesLine";
  RuleType2[RuleType2["_StepLine"] = 10] = "_StepLine";
  RuleType2[RuleType2["_DocStringSeparator"] = 11] = "_DocStringSeparator";
  RuleType2[RuleType2["_TableRow"] = 12] = "_TableRow";
  RuleType2[RuleType2["_Language"] = 13] = "_Language";
  RuleType2[RuleType2["_Other"] = 14] = "_Other";
  RuleType2[RuleType2["GherkinDocument"] = 15] = "GherkinDocument";
  RuleType2[RuleType2["Feature"] = 16] = "Feature";
  RuleType2[RuleType2["FeatureHeader"] = 17] = "FeatureHeader";
  RuleType2[RuleType2["Rule"] = 18] = "Rule";
  RuleType2[RuleType2["RuleHeader"] = 19] = "RuleHeader";
  RuleType2[RuleType2["Background"] = 20] = "Background";
  RuleType2[RuleType2["ScenarioDefinition"] = 21] = "ScenarioDefinition";
  RuleType2[RuleType2["Scenario"] = 22] = "Scenario";
  RuleType2[RuleType2["ExamplesDefinition"] = 23] = "ExamplesDefinition";
  RuleType2[RuleType2["Examples"] = 24] = "Examples";
  RuleType2[RuleType2["ExamplesTable"] = 25] = "ExamplesTable";
  RuleType2[RuleType2["Step"] = 26] = "Step";
  RuleType2[RuleType2["StepArg"] = 27] = "StepArg";
  RuleType2[RuleType2["DataTableAndMaybeDocString"] = 28] = "DataTableAndMaybeDocString";
  RuleType2[RuleType2["DocStringAndMaybeDataTable"] = 29] = "DocStringAndMaybeDataTable";
  RuleType2[RuleType2["DataTable"] = 30] = "DataTable";
  RuleType2[RuleType2["DocString"] = 31] = "DocString";
  RuleType2[RuleType2["Tags"] = 32] = "Tags";
  RuleType2[RuleType2["DescriptionHelper"] = 33] = "DescriptionHelper";
  RuleType2[RuleType2["Description"] = 34] = "Description";
})(RuleType || (RuleType = {}));
var Parser = class {
  builder;
  tokenMatcher;
  stopAtFirstError = false;
  context;
  constructor(builder, tokenMatcher) {
    this.builder = builder;
    this.tokenMatcher = tokenMatcher;
  }
  parse(gherkinSource) {
    const tokenScanner = new TokenScanner(gherkinSource, (line, location) => {
      const gherkinLine = line === null || line === void 0 ? null : new GherkinLine(line, location.line);
      return new Token(gherkinLine, location);
    });
    this.builder.reset();
    this.tokenMatcher.reset();
    this.context = {
      tokenScanner,
      tokenQueue: [],
      errors: []
    };
    this.startRule(this.context, RuleType.GherkinDocument);
    let state = 0;
    let token = null;
    while (true) {
      token = this.readToken(this.context);
      state = this.matchToken(state, token, this.context);
      if (token.isEof)
        break;
    }
    this.endRule(this.context);
    if (this.context.errors.length > 0) {
      throw CompositeParserException.create(this.context.errors);
    }
    return this.getResult();
  }
  addError(context, error) {
    if (!context.errors.map((e) => {
      return e.message;
    }).includes(error.message)) {
      context.errors.push(error);
      if (context.errors.length > 10)
        throw CompositeParserException.create(context.errors);
    }
  }
  startRule(context, ruleType) {
    this.handleAstError(context, () => this.builder.startRule(ruleType));
  }
  endRule(context) {
    this.handleAstError(context, () => this.builder.endRule());
  }
  build(context, token) {
    this.handleAstError(context, () => this.builder.build(token));
  }
  getResult() {
    return this.builder.getResult();
  }
  handleAstError(context, action) {
    this.handleExternalError(context, true, action);
  }
  handleExternalError(context, defaultValue, action) {
    if (this.stopAtFirstError)
      return action();
    try {
      return action();
    } catch (e) {
      if (e instanceof CompositeParserException) {
        e.errors.forEach((error) => this.addError(context, error));
      } else if (e instanceof ParserException || e instanceof AstBuilderException || e instanceof UnexpectedTokenException || e instanceof NoSuchLanguageException) {
        this.addError(context, e);
      } else {
        throw e;
      }
    }
    return defaultValue;
  }
  readToken(context) {
    return context.tokenQueue.length > 0 ? context.tokenQueue.shift() : context.tokenScanner.read();
  }
  matchToken(state, token, context) {
    switch (state) {
      case 0:
        return this.matchTokenAt_0(token, context);
      case 1:
        return this.matchTokenAt_1(token, context);
      case 2:
        return this.matchTokenAt_2(token, context);
      case 3:
        return this.matchTokenAt_3(token, context);
      case 4:
        return this.matchTokenAt_4(token, context);
      case 5:
        return this.matchTokenAt_5(token, context);
      case 6:
        return this.matchTokenAt_6(token, context);
      case 7:
        return this.matchTokenAt_7(token, context);
      case 8:
        return this.matchTokenAt_8(token, context);
      case 9:
        return this.matchTokenAt_9(token, context);
      case 10:
        return this.matchTokenAt_10(token, context);
      case 11:
        return this.matchTokenAt_11(token, context);
      case 12:
        return this.matchTokenAt_12(token, context);
      case 13:
        return this.matchTokenAt_13(token, context);
      case 14:
        return this.matchTokenAt_14(token, context);
      case 15:
        return this.matchTokenAt_15(token, context);
      case 16:
        return this.matchTokenAt_16(token, context);
      case 17:
        return this.matchTokenAt_17(token, context);
      case 18:
        return this.matchTokenAt_18(token, context);
      case 19:
        return this.matchTokenAt_19(token, context);
      case 20:
        return this.matchTokenAt_20(token, context);
      case 21:
        return this.matchTokenAt_21(token, context);
      case 22:
        return this.matchTokenAt_22(token, context);
      case 23:
        return this.matchTokenAt_23(token, context);
      case 24:
        return this.matchTokenAt_24(token, context);
      case 25:
        return this.matchTokenAt_25(token, context);
      case 26:
        return this.matchTokenAt_26(token, context);
      case 27:
        return this.matchTokenAt_27(token, context);
      case 28:
        return this.matchTokenAt_28(token, context);
      case 29:
        return this.matchTokenAt_29(token, context);
      case 30:
        return this.matchTokenAt_30(token, context);
      case 31:
        return this.matchTokenAt_31(token, context);
      case 32:
        return this.matchTokenAt_32(token, context);
      case 33:
        return this.matchTokenAt_33(token, context);
      case 34:
        return this.matchTokenAt_34(token, context);
      case 35:
        return this.matchTokenAt_35(token, context);
      case 36:
        return this.matchTokenAt_36(token, context);
      case 37:
        return this.matchTokenAt_37(token, context);
      case 38:
        return this.matchTokenAt_38(token, context);
      case 39:
        return this.matchTokenAt_39(token, context);
      case 40:
        return this.matchTokenAt_40(token, context);
      case 41:
        return this.matchTokenAt_41(token, context);
      case 43:
        return this.matchTokenAt_43(token, context);
      case 44:
        return this.matchTokenAt_44(token, context);
      case 45:
        return this.matchTokenAt_45(token, context);
      case 46:
        return this.matchTokenAt_46(token, context);
      case 47:
        return this.matchTokenAt_47(token, context);
      case 48:
        return this.matchTokenAt_48(token, context);
      case 49:
        return this.matchTokenAt_49(token, context);
      case 50:
        return this.matchTokenAt_50(token, context);
      case 51:
        return this.matchTokenAt_51(token, context);
      case 52:
        return this.matchTokenAt_52(token, context);
      case 53:
        return this.matchTokenAt_53(token, context);
      case 54:
        return this.matchTokenAt_54(token, context);
      default:
        throw new Error("Unknown state: " + state);
    }
  }
  // Start
  matchTokenAt_0(token, context) {
    if (this.match_EOF(context, token)) {
      this.build(context, token);
      return 42;
    }
    if (this.match_Language(context, token)) {
      this.startRule(context, RuleType.Feature);
      this.startRule(context, RuleType.FeatureHeader);
      this.build(context, token);
      return 1;
    }
    if (this.match_TagLine(context, token)) {
      this.startRule(context, RuleType.Feature);
      this.startRule(context, RuleType.FeatureHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 2;
    }
    if (this.match_FeatureLine(context, token)) {
      this.startRule(context, RuleType.Feature);
      this.startRule(context, RuleType.FeatureHeader);
      this.build(context, token);
      return 3;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 0;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 0;
    }
    const expectedTokens = ["#EOF", "#Language", "#TagLine", "#FeatureLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 0;
  }
  // GherkinDocument:0>Feature:0>FeatureHeader:0>#Language:0
  matchTokenAt_1(token, context) {
    if (this.match_TagLine(context, token)) {
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 2;
    }
    if (this.match_FeatureLine(context, token)) {
      this.build(context, token);
      return 3;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 1;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 1;
    }
    const expectedTokens = ["#TagLine", "#FeatureLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 1;
  }
  // GherkinDocument:0>Feature:0>FeatureHeader:1>Tags:0>#TagLine:0
  matchTokenAt_2(token, context) {
    if (this.match_TagLine(context, token)) {
      this.build(context, token);
      return 2;
    }
    if (this.match_FeatureLine(context, token)) {
      this.endRule(context);
      this.build(context, token);
      return 3;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 2;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 2;
    }
    const expectedTokens = ["#TagLine", "#FeatureLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 2;
  }
  // GherkinDocument:0>Feature:0>FeatureHeader:2>#FeatureLine:0
  matchTokenAt_3(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 3;
    }
    if (this.match_Comment(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 4;
    }
    if (this.match_BackgroundLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Background);
      this.build(context, token);
      return 5;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 4;
    }
    const expectedTokens = ["#EOF", "#Empty", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 3;
  }
  // GherkinDocument:0>Feature:0>FeatureHeader:3>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
  matchTokenAt_4(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 4;
    }
    if (this.match_BackgroundLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Background);
      this.build(context, token);
      return 5;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 4;
    }
    const expectedTokens = ["#EOF", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 4;
  }
  // GherkinDocument:0>Feature:1>Background:0>#BackgroundLine:0
  matchTokenAt_5(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 5;
    }
    if (this.match_Comment(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 6;
    }
    if (this.match_StepLine(context, token)) {
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 7;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 6;
    }
    const expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 5;
  }
  // GherkinDocument:0>Feature:1>Background:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
  matchTokenAt_6(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 6;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 7;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 6;
    }
    const expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 6;
  }
  // GherkinDocument:0>Feature:1>Background:2>Step:0>#StepLine:0
  matchTokenAt_7(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.startRule(context, RuleType.DataTable);
      this.build(context, token);
      return 8;
    }
    if (this.match_DocStringSeparator(context, token)) {
      this.startRule(context, RuleType.DocString);
      this.build(context, token);
      return 52;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 7;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 7;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 7;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 7;
  }
  // GherkinDocument:0>Feature:1>Background:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:0>DataTable:0>#TableRow:0
  matchTokenAt_8(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.build(context, token);
      return 8;
    }
    if (this.match_DocStringSeparator(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.DocString);
      this.build(context, token);
      return 9;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 7;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 8;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 8;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 8;
  }
  // GherkinDocument:0>Feature:1>Background:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:1>DocString:0>#DocStringSeparator:0
  matchTokenAt_9(token, context) {
    if (this.match_DocStringSeparator(context, token)) {
      this.build(context, token);
      return 10;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 9;
    }
    const expectedTokens = ["#DocStringSeparator", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 9;
  }
  // GherkinDocument:0>Feature:1>Background:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:1>DocString:2>#DocStringSeparator:0
  matchTokenAt_10(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 7;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 10;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 10;
    }
    const expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 10;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:0>Tags:0>#TagLine:0
  matchTokenAt_11(token, context) {
    if (this.match_TagLine(context, token)) {
      this.build(context, token);
      return 11;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 11;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 11;
    }
    const expectedTokens = ["#TagLine", "#ScenarioLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 11;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:0>#ScenarioLine:0
  matchTokenAt_12(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 12;
    }
    if (this.match_Comment(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 13;
    }
    if (this.match_StepLine(context, token)) {
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 14;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 18;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 13;
    }
    const expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 12;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
  matchTokenAt_13(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 13;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 14;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 18;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 13;
    }
    const expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 13;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:0>#StepLine:0
  matchTokenAt_14(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.startRule(context, RuleType.DataTable);
      this.build(context, token);
      return 15;
    }
    if (this.match_DocStringSeparator(context, token)) {
      this.startRule(context, RuleType.DocString);
      this.build(context, token);
      return 49;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 14;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 18;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 14;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 14;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 14;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:0>DataTable:0>#TableRow:0
  matchTokenAt_15(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.build(context, token);
      return 15;
    }
    if (this.match_DocStringSeparator(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.DocString);
      this.build(context, token);
      return 16;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 14;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 18;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 15;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 15;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 15;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:1>DocString:0>#DocStringSeparator:0
  matchTokenAt_16(token, context) {
    if (this.match_DocStringSeparator(context, token)) {
      this.build(context, token);
      return 17;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 16;
    }
    const expectedTokens = ["#DocStringSeparator", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 16;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:1>DocString:2>#DocStringSeparator:0
  matchTokenAt_17(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 14;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 18;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 17;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 17;
    }
    const expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 17;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:0>Tags:0>#TagLine:0
  matchTokenAt_18(token, context) {
    if (this.match_TagLine(context, token)) {
      this.build(context, token);
      return 18;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 18;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 18;
    }
    const expectedTokens = ["#TagLine", "#ExamplesLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 18;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:0>#ExamplesLine:0
  matchTokenAt_19(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 19;
    }
    if (this.match_Comment(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 20;
    }
    if (this.match_TableRow(context, token)) {
      this.startRule(context, RuleType.ExamplesTable);
      this.build(context, token);
      return 21;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 18;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 20;
    }
    const expectedTokens = ["#EOF", "#Empty", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 19;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
  matchTokenAt_20(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 20;
    }
    if (this.match_TableRow(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesTable);
      this.build(context, token);
      return 21;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 18;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 20;
    }
    const expectedTokens = ["#EOF", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 20;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:2>ExamplesTable:0>#TableRow:0
  matchTokenAt_21(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.build(context, token);
      return 21;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 18;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 21;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 21;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 21;
  }
  // GherkinDocument:0>Feature:3>Rule:0>RuleHeader:0>Tags:0>#TagLine:0
  matchTokenAt_22(token, context) {
    if (this.match_TagLine(context, token)) {
      this.build(context, token);
      return 22;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 22;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 22;
    }
    const expectedTokens = ["#TagLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 22;
  }
  // GherkinDocument:0>Feature:3>Rule:0>RuleHeader:1>#RuleLine:0
  matchTokenAt_23(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 24;
    }
    if (this.match_BackgroundLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Background);
      this.build(context, token);
      return 25;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 24;
    }
    const expectedTokens = ["#EOF", "#Empty", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 23;
  }
  // GherkinDocument:0>Feature:3>Rule:0>RuleHeader:2>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
  matchTokenAt_24(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 24;
    }
    if (this.match_BackgroundLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Background);
      this.build(context, token);
      return 25;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 24;
    }
    const expectedTokens = ["#EOF", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 24;
  }
  // GherkinDocument:0>Feature:3>Rule:1>Background:0>#BackgroundLine:0
  matchTokenAt_25(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 25;
    }
    if (this.match_Comment(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 26;
    }
    if (this.match_StepLine(context, token)) {
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 27;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 26;
    }
    const expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 25;
  }
  // GherkinDocument:0>Feature:3>Rule:1>Background:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
  matchTokenAt_26(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 26;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 27;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 26;
    }
    const expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 26;
  }
  // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:0>#StepLine:0
  matchTokenAt_27(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.startRule(context, RuleType.DataTable);
      this.build(context, token);
      return 28;
    }
    if (this.match_DocStringSeparator(context, token)) {
      this.startRule(context, RuleType.DocString);
      this.build(context, token);
      return 46;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 27;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 27;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 27;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 27;
  }
  // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:0>DataTable:0>#TableRow:0
  matchTokenAt_28(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.build(context, token);
      return 28;
    }
    if (this.match_DocStringSeparator(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.DocString);
      this.build(context, token);
      return 29;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 27;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 28;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 28;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 28;
  }
  // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:1>DocString:0>#DocStringSeparator:0
  matchTokenAt_29(token, context) {
    if (this.match_DocStringSeparator(context, token)) {
      this.build(context, token);
      return 30;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 29;
    }
    const expectedTokens = ["#DocStringSeparator", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 29;
  }
  // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:1>DocString:2>#DocStringSeparator:0
  matchTokenAt_30(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 27;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 30;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 30;
    }
    const expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 30;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:0>Tags:0>#TagLine:0
  matchTokenAt_31(token, context) {
    if (this.match_TagLine(context, token)) {
      this.build(context, token);
      return 31;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 31;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 31;
    }
    const expectedTokens = ["#TagLine", "#ScenarioLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 31;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:0>#ScenarioLine:0
  matchTokenAt_32(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 32;
    }
    if (this.match_Comment(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 33;
    }
    if (this.match_StepLine(context, token)) {
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 34;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 38;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 33;
    }
    const expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 32;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
  matchTokenAt_33(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 33;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 34;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 38;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 33;
    }
    const expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 33;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:0>#StepLine:0
  matchTokenAt_34(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.startRule(context, RuleType.DataTable);
      this.build(context, token);
      return 35;
    }
    if (this.match_DocStringSeparator(context, token)) {
      this.startRule(context, RuleType.DocString);
      this.build(context, token);
      return 43;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 34;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 38;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 34;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 34;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 34;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:0>DataTable:0>#TableRow:0
  matchTokenAt_35(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.build(context, token);
      return 35;
    }
    if (this.match_DocStringSeparator(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.DocString);
      this.build(context, token);
      return 36;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 34;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 38;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 35;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 35;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 35;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:1>DocString:0>#DocStringSeparator:0
  matchTokenAt_36(token, context) {
    if (this.match_DocStringSeparator(context, token)) {
      this.build(context, token);
      return 37;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 36;
    }
    const expectedTokens = ["#DocStringSeparator", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 36;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:0>DataTableAndMaybeDocString:1>DocString:2>#DocStringSeparator:0
  matchTokenAt_37(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 34;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 38;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 37;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 37;
    }
    const expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 37;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:0>Tags:0>#TagLine:0
  matchTokenAt_38(token, context) {
    if (this.match_TagLine(context, token)) {
      this.build(context, token);
      return 38;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 38;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 38;
    }
    const expectedTokens = ["#TagLine", "#ExamplesLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 38;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:0>#ExamplesLine:0
  matchTokenAt_39(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 39;
    }
    if (this.match_Comment(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 40;
    }
    if (this.match_TableRow(context, token)) {
      this.startRule(context, RuleType.ExamplesTable);
      this.build(context, token);
      return 41;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 38;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.startRule(context, RuleType.Description);
      this.build(context, token);
      return 40;
    }
    const expectedTokens = ["#EOF", "#Empty", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 39;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:1>DescriptionHelper:1>Description:0>__alt1:0>#Other:0
  matchTokenAt_40(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 40;
    }
    if (this.match_TableRow(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesTable);
      this.build(context, token);
      return 41;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 38;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 40;
    }
    const expectedTokens = ["#EOF", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 40;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:3>ExamplesDefinition:1>Examples:2>ExamplesTable:0>#TableRow:0
  matchTokenAt_41(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.build(context, token);
      return 41;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 38;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 41;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 41;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 41;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:0>DocString:0>#DocStringSeparator:0
  matchTokenAt_43(token, context) {
    if (this.match_DocStringSeparator(context, token)) {
      this.build(context, token);
      return 44;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 43;
    }
    const expectedTokens = ["#DocStringSeparator", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 43;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:0>DocString:2>#DocStringSeparator:0
  matchTokenAt_44(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.DataTable);
      this.build(context, token);
      return 45;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 34;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 38;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 44;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 44;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 44;
  }
  // GherkinDocument:0>Feature:3>Rule:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:1>DataTable:0>#TableRow:0
  matchTokenAt_45(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.build(context, token);
      return 45;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 34;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 38;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 39;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 45;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 45;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 45;
  }
  // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:0>DocString:0>#DocStringSeparator:0
  matchTokenAt_46(token, context) {
    if (this.match_DocStringSeparator(context, token)) {
      this.build(context, token);
      return 47;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 46;
    }
    const expectedTokens = ["#DocStringSeparator", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 46;
  }
  // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:0>DocString:2>#DocStringSeparator:0
  matchTokenAt_47(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.DataTable);
      this.build(context, token);
      return 48;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 27;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 47;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 47;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 47;
  }
  // GherkinDocument:0>Feature:3>Rule:1>Background:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:1>DataTable:0>#TableRow:0
  matchTokenAt_48(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.build(context, token);
      return 48;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 27;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 31;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 32;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 48;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 48;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 48;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:0>DocString:0>#DocStringSeparator:0
  matchTokenAt_49(token, context) {
    if (this.match_DocStringSeparator(context, token)) {
      this.build(context, token);
      return 50;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 49;
    }
    const expectedTokens = ["#DocStringSeparator", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 49;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:0>DocString:2>#DocStringSeparator:0
  matchTokenAt_50(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.DataTable);
      this.build(context, token);
      return 51;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 14;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 18;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 50;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 50;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 50;
  }
  // GherkinDocument:0>Feature:2>ScenarioDefinition:1>Scenario:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:1>DataTable:0>#TableRow:0
  matchTokenAt_51(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.build(context, token);
      return 51;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 14;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_1(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ExamplesDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 18;
      }
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ExamplesLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ExamplesDefinition);
      this.startRule(context, RuleType.Examples);
      this.build(context, token);
      return 19;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 51;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 51;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 51;
  }
  // GherkinDocument:0>Feature:1>Background:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:0>DocString:0>#DocStringSeparator:0
  matchTokenAt_52(token, context) {
    if (this.match_DocStringSeparator(context, token)) {
      this.build(context, token);
      return 53;
    }
    if (this.match_Other(context, token)) {
      this.build(context, token);
      return 52;
    }
    const expectedTokens = ["#DocStringSeparator", "#Other"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 52;
  }
  // GherkinDocument:0>Feature:1>Background:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:0>DocString:2>#DocStringSeparator:0
  matchTokenAt_53(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.endRule(context);
      this.startRule(context, RuleType.DataTable);
      this.build(context, token);
      return 54;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 7;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 53;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 53;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 53;
  }
  // GherkinDocument:0>Feature:1>Background:2>Step:1>StepArg:0>__alt0:1>DocStringAndMaybeDataTable:1>DataTable:0>#TableRow:0
  matchTokenAt_54(token, context) {
    if (this.match_EOF(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.build(context, token);
      return 42;
    }
    if (this.match_TableRow(context, token)) {
      this.build(context, token);
      return 54;
    }
    if (this.match_StepLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Step);
      this.build(context, token);
      return 7;
    }
    if (this.match_TagLine(context, token)) {
      if (this.lookahead_0(context, token)) {
        this.endRule(context);
        this.endRule(context);
        this.endRule(context);
        this.startRule(context, RuleType.ScenarioDefinition);
        this.startRule(context, RuleType.Tags);
        this.build(context, token);
        return 11;
      }
    }
    if (this.match_TagLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.startRule(context, RuleType.Tags);
      this.build(context, token);
      return 22;
    }
    if (this.match_ScenarioLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.ScenarioDefinition);
      this.startRule(context, RuleType.Scenario);
      this.build(context, token);
      return 12;
    }
    if (this.match_RuleLine(context, token)) {
      this.endRule(context);
      this.endRule(context);
      this.endRule(context);
      this.startRule(context, RuleType.Rule);
      this.startRule(context, RuleType.RuleHeader);
      this.build(context, token);
      return 23;
    }
    if (this.match_Comment(context, token)) {
      this.build(context, token);
      return 54;
    }
    if (this.match_Empty(context, token)) {
      this.build(context, token);
      return 54;
    }
    const expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ScenarioLine", "#RuleLine", "#Comment", "#Empty"];
    const error = token.isEof ? UnexpectedEOFException.create(token, expectedTokens) : UnexpectedTokenException.create(token, expectedTokens);
    if (this.stopAtFirstError)
      throw error;
    this.addError(context, error);
    return 54;
  }
  match_EOF(context, token) {
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_EOF(token));
  }
  match_Empty(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_Empty(token));
  }
  match_Comment(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_Comment(token));
  }
  match_TagLine(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_TagLine(token));
  }
  match_FeatureLine(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_FeatureLine(token));
  }
  match_RuleLine(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_RuleLine(token));
  }
  match_BackgroundLine(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_BackgroundLine(token));
  }
  match_ScenarioLine(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_ScenarioLine(token));
  }
  match_ExamplesLine(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_ExamplesLine(token));
  }
  match_StepLine(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_StepLine(token));
  }
  match_DocStringSeparator(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_DocStringSeparator(token));
  }
  match_TableRow(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_TableRow(token));
  }
  match_Language(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_Language(token));
  }
  match_Other(context, token) {
    if (token.isEof)
      return false;
    return this.handleExternalError(context, false, () => this.tokenMatcher.match_Other(token));
  }
  lookahead_0(context, currentToken) {
    let token;
    const queue = [];
    let match = false;
    do {
      token = this.readToken(this.context);
      queue.push(token);
      if (this.match_ScenarioLine(context, token)) {
        match = true;
        break;
      }
    } while (this.match_Empty(context, token) || this.match_Comment(context, token) || this.match_TagLine(context, token));
    context.tokenQueue = context.tokenQueue.concat(queue);
    return match;
  }
  lookahead_1(context, currentToken) {
    let token;
    const queue = [];
    let match = false;
    do {
      token = this.readToken(this.context);
      queue.push(token);
      if (this.match_ExamplesLine(context, token)) {
        match = true;
        break;
      }
    } while (this.match_Empty(context, token) || this.match_Comment(context, token) || this.match_TagLine(context, token));
    context.tokenQueue = context.tokenQueue.concat(queue);
    return match;
  }
};

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/AstBuilder.js
var AstBuilder = class {
  stack;
  comments;
  newId;
  constructor(newId) {
    this.newId = newId;
    if (!newId) {
      throw new Error("No newId");
    }
    this.reset();
  }
  reset() {
    this.stack = [new AstNode(RuleType.None)];
    this.comments = [];
  }
  startRule(ruleType) {
    this.stack.push(new AstNode(ruleType));
  }
  endRule() {
    const node = this.stack.pop();
    const transformedNode = this.transformNode(node);
    this.currentNode().add(node.ruleType, transformedNode);
  }
  build(token) {
    if (token.matchedType === TokenType.Comment) {
      this.comments.push({
        location: this.getLocation(token),
        text: token.matchedText
      });
    } else {
      this.currentNode().add(token.matchedType, token);
    }
  }
  getResult() {
    return this.currentNode().getSingle(RuleType.GherkinDocument);
  }
  currentNode() {
    return this.stack[this.stack.length - 1];
  }
  getLocation(token, column) {
    return !column ? token.location : { line: token.location.line, column };
  }
  getTags(node) {
    const tags = [];
    const tagsNode = node.getSingle(RuleType.Tags);
    if (!tagsNode) {
      return tags;
    }
    const tokens = tagsNode.getTokens(TokenType.TagLine);
    for (const token of tokens) {
      for (const tagItem of token.matchedItems) {
        tags.push({
          location: this.getLocation(token, tagItem.column),
          name: tagItem.text,
          id: this.newId()
        });
      }
    }
    return tags;
  }
  getCells(tableRowToken) {
    return tableRowToken.matchedItems.map((cellItem) => ({
      location: this.getLocation(tableRowToken, cellItem.column),
      value: cellItem.text
    }));
  }
  getDescription(node) {
    return node.getSingle(RuleType.Description) || "";
  }
  getSteps(node) {
    return node.getItems(RuleType.Step);
  }
  getTableRows(node) {
    const rows = node.getTokens(TokenType.TableRow).map((token) => ({
      id: this.newId(),
      location: this.getLocation(token),
      cells: this.getCells(token)
    }));
    this.ensureCellCount(rows);
    return rows.length === 0 ? [] : rows;
  }
  ensureCellCount(rows) {
    if (rows.length === 0) {
      return;
    }
    const cellCount = rows[0].cells.length;
    rows.forEach((row) => {
      if (row.cells.length !== cellCount) {
        throw AstBuilderException.create("inconsistent cell count within the table", row.location);
      }
    });
  }
  transformNode(node) {
    switch (node.ruleType) {
      case RuleType.Step: {
        const stepLine = node.getToken(TokenType.StepLine);
        const dataTable = node.getSingle(RuleType.DataTable);
        const docString = node.getSingle(RuleType.DocString);
        const location = this.getLocation(stepLine);
        const step = {
          id: this.newId(),
          location,
          keyword: stepLine.matchedKeyword,
          keywordType: stepLine.matchedKeywordType,
          text: stepLine.matchedText,
          dataTable,
          docString
        };
        return step;
      }
      case RuleType.DocString: {
        const separatorToken = node.getTokens(TokenType.DocStringSeparator)[0];
        const mediaType = separatorToken.matchedText.length > 0 ? separatorToken.matchedText : void 0;
        const lineTokens = node.getTokens(TokenType.Other);
        const content = lineTokens.map((t) => t.matchedText).join("\n");
        const result = {
          location: this.getLocation(separatorToken),
          content,
          delimiter: separatorToken.matchedKeyword
        };
        if (mediaType) {
          result.mediaType = mediaType;
        }
        return result;
      }
      case RuleType.DataTable: {
        const rows = this.getTableRows(node);
        const dataTable = {
          location: rows[0].location,
          rows
        };
        return dataTable;
      }
      case RuleType.Background: {
        const backgroundLine = node.getToken(TokenType.BackgroundLine);
        const description = this.getDescription(node);
        const steps = this.getSteps(node);
        const background = {
          id: this.newId(),
          location: this.getLocation(backgroundLine),
          keyword: backgroundLine.matchedKeyword,
          name: backgroundLine.matchedText,
          description,
          steps
        };
        return background;
      }
      case RuleType.ScenarioDefinition: {
        const tags = this.getTags(node);
        const scenarioNode = node.getSingle(RuleType.Scenario);
        const scenarioLine = scenarioNode.getToken(TokenType.ScenarioLine);
        const description = this.getDescription(scenarioNode);
        const steps = this.getSteps(scenarioNode);
        const examples = scenarioNode.getItems(RuleType.ExamplesDefinition);
        const scenario = {
          id: this.newId(),
          tags,
          location: this.getLocation(scenarioLine),
          keyword: scenarioLine.matchedKeyword,
          name: scenarioLine.matchedText,
          description,
          steps,
          examples
        };
        return scenario;
      }
      case RuleType.ExamplesDefinition: {
        const tags = this.getTags(node);
        const examplesNode = node.getSingle(RuleType.Examples);
        const examplesLine = examplesNode.getToken(TokenType.ExamplesLine);
        const description = this.getDescription(examplesNode);
        const examplesTable = examplesNode.getSingle(RuleType.ExamplesTable);
        const examples = {
          id: this.newId(),
          tags,
          location: this.getLocation(examplesLine),
          keyword: examplesLine.matchedKeyword,
          name: examplesLine.matchedText,
          description,
          tableHeader: examplesTable ? examplesTable[0] : void 0,
          tableBody: examplesTable ? examplesTable.slice(1) : []
        };
        return examples;
      }
      case RuleType.ExamplesTable: {
        return this.getTableRows(node);
      }
      case RuleType.Description: {
        let lineTokens = node.getTokens(TokenType.Other);
        let end = lineTokens.length;
        while (end > 0 && lineTokens[end - 1].line.trimmedLineText === "") {
          end--;
        }
        lineTokens = lineTokens.slice(0, end);
        return lineTokens.map((token) => token.matchedText).join("\n");
      }
      case RuleType.Feature: {
        const header = node.getSingle(RuleType.FeatureHeader);
        if (!header) {
          return null;
        }
        const tags = this.getTags(header);
        const featureLine = header.getToken(TokenType.FeatureLine);
        if (!featureLine) {
          return null;
        }
        const children = [];
        const background = node.getSingle(RuleType.Background);
        if (background) {
          children.push({
            background
          });
        }
        for (const scenario of node.getItems(RuleType.ScenarioDefinition)) {
          children.push({
            scenario
          });
        }
        for (const rule of node.getItems(RuleType.Rule)) {
          children.push({
            rule
          });
        }
        const description = this.getDescription(header);
        const language = featureLine.matchedGherkinDialect;
        const feature = {
          tags,
          location: this.getLocation(featureLine),
          language,
          keyword: featureLine.matchedKeyword,
          name: featureLine.matchedText,
          description,
          children
        };
        return feature;
      }
      case RuleType.Rule: {
        const header = node.getSingle(RuleType.RuleHeader);
        if (!header) {
          return null;
        }
        const ruleLine = header.getToken(TokenType.RuleLine);
        if (!ruleLine) {
          return null;
        }
        const tags = this.getTags(header);
        const children = [];
        const background = node.getSingle(RuleType.Background);
        if (background) {
          children.push({
            background
          });
        }
        for (const scenario of node.getItems(RuleType.ScenarioDefinition)) {
          children.push({
            scenario
          });
        }
        const description = this.getDescription(header);
        const rule = {
          id: this.newId(),
          location: this.getLocation(ruleLine),
          keyword: ruleLine.matchedKeyword,
          name: ruleLine.matchedText,
          description,
          children,
          tags
        };
        return rule;
      }
      case RuleType.GherkinDocument: {
        const feature = node.getSingle(RuleType.Feature);
        const gherkinDocument = {
          feature,
          comments: this.comments
        };
        return gherkinDocument;
      }
      default:
        return node;
    }
  }
};

// node_modules/.pnpm/@cucumber+messages@34.2.1/node_modules/@cucumber/messages/dist/messages.js
var AttachmentContentEncoding;
(function(AttachmentContentEncoding2) {
  AttachmentContentEncoding2["IDENTITY"] = "IDENTITY";
  AttachmentContentEncoding2["BASE64"] = "BASE64";
})(AttachmentContentEncoding || (AttachmentContentEncoding = {}));
var HookType;
(function(HookType2) {
  HookType2["BEFORE_TEST_RUN"] = "BEFORE_TEST_RUN";
  HookType2["AFTER_TEST_RUN"] = "AFTER_TEST_RUN";
  HookType2["BEFORE_TEST_CASE"] = "BEFORE_TEST_CASE";
  HookType2["AFTER_TEST_CASE"] = "AFTER_TEST_CASE";
  HookType2["BEFORE_TEST_STEP"] = "BEFORE_TEST_STEP";
  HookType2["AFTER_TEST_STEP"] = "AFTER_TEST_STEP";
})(HookType || (HookType = {}));
var PickleStepType;
(function(PickleStepType2) {
  PickleStepType2["UNKNOWN"] = "Unknown";
  PickleStepType2["CONTEXT"] = "Context";
  PickleStepType2["ACTION"] = "Action";
  PickleStepType2["OUTCOME"] = "Outcome";
})(PickleStepType || (PickleStepType = {}));
var SourceMediaType;
(function(SourceMediaType2) {
  SourceMediaType2["TEXT_X_CUCUMBER_GHERKIN_PLAIN"] = "text/x.cucumber.gherkin+plain";
  SourceMediaType2["TEXT_X_CUCUMBER_GHERKIN_MARKDOWN"] = "text/x.cucumber.gherkin+markdown";
})(SourceMediaType || (SourceMediaType = {}));
var StepDefinitionPatternType;
(function(StepDefinitionPatternType2) {
  StepDefinitionPatternType2["CUCUMBER_EXPRESSION"] = "CUCUMBER_EXPRESSION";
  StepDefinitionPatternType2["REGULAR_EXPRESSION"] = "REGULAR_EXPRESSION";
})(StepDefinitionPatternType || (StepDefinitionPatternType = {}));
var StepKeywordType;
(function(StepKeywordType2) {
  StepKeywordType2["UNKNOWN"] = "Unknown";
  StepKeywordType2["CONTEXT"] = "Context";
  StepKeywordType2["ACTION"] = "Action";
  StepKeywordType2["OUTCOME"] = "Outcome";
  StepKeywordType2["CONJUNCTION"] = "Conjunction";
})(StepKeywordType || (StepKeywordType = {}));
var TestStepResultStatus;
(function(TestStepResultStatus2) {
  TestStepResultStatus2["UNKNOWN"] = "UNKNOWN";
  TestStepResultStatus2["PASSED"] = "PASSED";
  TestStepResultStatus2["SKIPPED"] = "SKIPPED";
  TestStepResultStatus2["PENDING"] = "PENDING";
  TestStepResultStatus2["UNDEFINED"] = "UNDEFINED";
  TestStepResultStatus2["AMBIGUOUS"] = "AMBIGUOUS";
  TestStepResultStatus2["FAILED"] = "FAILED";
})(TestStepResultStatus || (TestStepResultStatus = {}));

// node_modules/.pnpm/@cucumber+messages@34.2.1/node_modules/@cucumber/messages/dist/IdGenerator.js
var IdGenerator_exports = {};
__export(IdGenerator_exports, {
  incrementing: () => incrementing,
  uuid: () => uuid
});
function uuid() {
  return () => crypto.randomUUID();
}
function incrementing() {
  let next = 0;
  return () => (next++).toString();
}

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/compareStepKeywords.js
function compareStepKeywords(a, b) {
  return b.length - a.length;
}

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/gherkin-languages.json
var gherkin_languages_default = {
  af: {
    and: [
      "* ",
      "En "
    ],
    background: [
      "Agtergrond"
    ],
    but: [
      "* ",
      "Maar "
    ],
    examples: [
      "Voorbeelde"
    ],
    feature: [
      "Funksie",
      "Besigheid Behoefte",
      "Vermo\xEB"
    ],
    given: [
      "* ",
      "Gegewe "
    ],
    name: "Afrikaans",
    native: "Afrikaans",
    rule: [
      "Re\xEBl",
      "Reel"
    ],
    scenario: [
      "Voorbeeld",
      "Situasie"
    ],
    scenarioOutline: [
      "Situasie Uiteensetting"
    ],
    then: [
      "* ",
      "Dan "
    ],
    when: [
      "* ",
      "Wanneer "
    ]
  },
  am: {
    and: [
      "* ",
      "\u0535\u057E "
    ],
    background: [
      "\u053F\u0578\u0576\u057F\u0565\u0584\u057D\u057F"
    ],
    but: [
      "* ",
      "\u0532\u0561\u0575\u0581 "
    ],
    examples: [
      "\u0555\u0580\u056B\u0576\u0561\u056F\u0576\u0565\u0580"
    ],
    feature: [
      "\u0556\u0578\u0582\u0576\u056F\u0581\u056B\u0578\u0576\u0561\u056C\u0578\u0582\u0569\u0575\u0578\u0582\u0576",
      "\u0540\u0561\u057F\u056F\u0578\u0582\u0569\u0575\u0578\u0582\u0576"
    ],
    given: [
      "* ",
      "\u0534\u056B\u0581\u0578\u0582\u0584 "
    ],
    name: "Armenian",
    native: "\u0570\u0561\u0575\u0565\u0580\u0565\u0576",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0555\u0580\u056B\u0576\u0561\u056F",
      "\u054D\u0581\u0565\u0576\u0561\u0580"
    ],
    scenarioOutline: [
      "\u054D\u0581\u0565\u0576\u0561\u0580\u056B \u056F\u0561\u057C\u0578\u0582\u0581\u057E\u0561\u0581\u0584\u0568"
    ],
    then: [
      "* ",
      "\u0531\u057A\u0561 "
    ],
    when: [
      "* ",
      "\u0535\u0569\u0565 ",
      "\u0535\u0580\u0562 "
    ]
  },
  an: {
    and: [
      "* ",
      "Y ",
      "E "
    ],
    background: [
      "Antecedents"
    ],
    but: [
      "* ",
      "Pero "
    ],
    examples: [
      "Eixemplos"
    ],
    feature: [
      "Caracteristica"
    ],
    given: [
      "* ",
      "Dau ",
      "Dada ",
      "Daus ",
      "Dadas "
    ],
    name: "Aragonese",
    native: "Aragon\xE9s",
    rule: [
      "Rule"
    ],
    scenario: [
      "Eixemplo",
      "Caso"
    ],
    scenarioOutline: [
      "Esquema del caso"
    ],
    then: [
      "* ",
      "Alavez ",
      "Allora ",
      "Antonces "
    ],
    when: [
      "* ",
      "Cuan "
    ]
  },
  ar: {
    and: [
      "* ",
      "\u0648 "
    ],
    background: [
      "\u0627\u0644\u062E\u0644\u0641\u064A\u0629"
    ],
    but: [
      "* ",
      "\u0644\u0643\u0646 "
    ],
    examples: [
      "\u0627\u0645\u062B\u0644\u0629"
    ],
    feature: [
      "\u062E\u0627\u0635\u064A\u0629"
    ],
    given: [
      "* ",
      "\u0628\u0641\u0631\u0636 "
    ],
    name: "Arabic",
    native: "\u0627\u0644\u0639\u0631\u0628\u064A\u0629",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0645\u062B\u0627\u0644",
      "\u0633\u064A\u0646\u0627\u0631\u064A\u0648"
    ],
    scenarioOutline: [
      "\u0633\u064A\u0646\u0627\u0631\u064A\u0648 \u0645\u062E\u0637\u0637"
    ],
    then: [
      "* ",
      "\u0627\u0630\u0627\u064B ",
      "\u062B\u0645 "
    ],
    when: [
      "* ",
      "\u0645\u062A\u0649 ",
      "\u0639\u0646\u062F\u0645\u0627 "
    ]
  },
  ast: {
    and: [
      "* ",
      "Y ",
      "Ya "
    ],
    background: [
      "Antecedentes"
    ],
    but: [
      "* ",
      "Peru "
    ],
    examples: [
      "Exemplos"
    ],
    feature: [
      "Carauter\xEDstica"
    ],
    given: [
      "* ",
      "D\xE1u ",
      "Dada ",
      "Daos ",
      "Daes "
    ],
    name: "Asturian",
    native: "asturianu",
    rule: [
      "Rule"
    ],
    scenario: [
      "Exemplo",
      "Casu"
    ],
    scenarioOutline: [
      "Esbozu del casu"
    ],
    then: [
      "* ",
      "Ent\xF3s "
    ],
    when: [
      "* ",
      "Cuando "
    ]
  },
  az: {
    and: [
      "* ",
      "V\u0259 ",
      "H\u0259m "
    ],
    background: [
      "Ke\xE7mi\u015F",
      "Kontekst"
    ],
    but: [
      "* ",
      "Amma ",
      "Ancaq "
    ],
    examples: [
      "N\xFCmun\u0259l\u0259r"
    ],
    feature: [
      "\xD6z\u0259llik"
    ],
    given: [
      "* ",
      "Tutaq ki ",
      "Verilir "
    ],
    name: "Azerbaijani",
    native: "Az\u0259rbaycanca",
    rule: [
      "Rule"
    ],
    scenario: [
      "N\xFCmun\u0259",
      "Ssenari"
    ],
    scenarioOutline: [
      "Ssenarinin strukturu"
    ],
    then: [
      "* ",
      "O halda "
    ],
    when: [
      "* ",
      "\u018Fg\u0259r ",
      "N\u0259 vaxt ki "
    ]
  },
  be: {
    and: [
      "* ",
      "I ",
      "\u0414\u044B ",
      "\u0422\u0430\u043A\u0441\u0430\u043C\u0430 "
    ],
    background: [
      "\u041A\u0430\u043D\u0442\u044D\u043A\u0441\u0442"
    ],
    but: [
      "* ",
      "\u0410\u043B\u0435 ",
      "\u0406\u043D\u0430\u043A\u0448 "
    ],
    examples: [
      "\u041F\u0440\u044B\u043A\u043B\u0430\u0434\u044B"
    ],
    feature: [
      "\u0424\u0443\u043D\u043A\u0446\u044B\u044F\u043D\u0430\u043B\u044C\u043D\u0430\u0441\u0446\u044C",
      "\u0424\u0456\u0447\u0430"
    ],
    given: [
      "* ",
      "\u041D\u044F\u0445\u0430\u0439 ",
      "\u0414\u0430\u0434\u0437\u0435\u043D\u0430 "
    ],
    name: "Belarusian",
    native: "\u0411\u0435\u043B\u0430\u0440\u0443\u0441\u043A\u0430\u044F",
    rule: [
      "\u041F\u0440\u0430\u0432\u0456\u043B\u044B"
    ],
    scenario: [
      "\u0421\u0446\u044D\u043D\u0430\u0440\u044B\u0439",
      "C\u0446\u044D\u043D\u0430\u0440"
    ],
    scenarioOutline: [
      "\u0428\u0430\u0431\u043B\u043E\u043D \u0441\u0446\u044D\u043D\u0430\u0440\u044B\u044F",
      "\u0423\u0437\u043E\u0440 \u0441\u0446\u044D\u043D\u0430\u0440\u0430"
    ],
    then: [
      "* ",
      "\u0422\u0430\u0434\u044B "
    ],
    when: [
      "* ",
      "\u041A\u0430\u043B\u0456 "
    ]
  },
  bg: {
    and: [
      "* ",
      "\u0418 "
    ],
    background: [
      "\u041F\u0440\u0435\u0434\u0438\u0441\u0442\u043E\u0440\u0438\u044F"
    ],
    but: [
      "* ",
      "\u041D\u043E "
    ],
    examples: [
      "\u041F\u0440\u0438\u043C\u0435\u0440\u0438"
    ],
    feature: [
      "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B\u043D\u043E\u0441\u0442"
    ],
    given: [
      "* ",
      "\u0414\u0430\u0434\u0435\u043D\u043E "
    ],
    name: "Bulgarian",
    native: "\u0431\u044A\u043B\u0433\u0430\u0440\u0441\u043A\u0438",
    rule: [
      "\u041F\u0440\u0430\u0432\u0438\u043B\u043E"
    ],
    scenario: [
      "\u041F\u0440\u0438\u043C\u0435\u0440",
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439"
    ],
    scenarioOutline: [
      "\u0420\u0430\u043C\u043A\u0430 \u043D\u0430 \u0441\u0446\u0435\u043D\u0430\u0440\u0438\u0439"
    ],
    then: [
      "* ",
      "\u0422\u043E "
    ],
    when: [
      "* ",
      "\u041A\u043E\u0433\u0430\u0442\u043E "
    ]
  },
  bm: {
    and: [
      "* ",
      "Dan "
    ],
    background: [
      "Latar Belakang"
    ],
    but: [
      "* ",
      "Tetapi ",
      "Tapi "
    ],
    examples: [
      "Contoh"
    ],
    feature: [
      "Fungsi"
    ],
    given: [
      "* ",
      "Diberi ",
      "Bagi "
    ],
    name: "Malay",
    native: "Bahasa Melayu",
    rule: [
      "Rule"
    ],
    scenario: [
      "Senario",
      "Situasi",
      "Keadaan"
    ],
    scenarioOutline: [
      "Kerangka Senario",
      "Kerangka Situasi",
      "Kerangka Keadaan",
      "Garis Panduan Senario"
    ],
    then: [
      "* ",
      "Maka ",
      "Kemudian "
    ],
    when: [
      "* ",
      "Apabila "
    ]
  },
  bs: {
    and: [
      "* ",
      "I ",
      "A "
    ],
    background: [
      "Pozadina"
    ],
    but: [
      "* ",
      "Ali "
    ],
    examples: [
      "Primjeri"
    ],
    feature: [
      "Karakteristika"
    ],
    given: [
      "* ",
      "Dato "
    ],
    name: "Bosnian",
    native: "Bosanski",
    rule: [
      "Rule"
    ],
    scenario: [
      "Primjer",
      "Scenariju",
      "Scenario"
    ],
    scenarioOutline: [
      "Scenariju-obris",
      "Scenario-outline"
    ],
    then: [
      "* ",
      "Zatim "
    ],
    when: [
      "* ",
      "Kada "
    ]
  },
  ca: {
    and: [
      "* ",
      "I "
    ],
    background: [
      "Rerefons",
      "Antecedents"
    ],
    but: [
      "* ",
      "Per\xF2 "
    ],
    examples: [
      "Exemples"
    ],
    feature: [
      "Caracter\xEDstica",
      "Funcionalitat"
    ],
    given: [
      "* ",
      "Donat ",
      "Donada ",
      "At\xE8s ",
      "Atesa "
    ],
    name: "Catalan",
    native: "catal\xE0",
    rule: [
      "Rule"
    ],
    scenario: [
      "Exemple",
      "Escenari"
    ],
    scenarioOutline: [
      "Esquema de l'escenari"
    ],
    then: [
      "* ",
      "Aleshores ",
      "Cal "
    ],
    when: [
      "* ",
      "Quan "
    ]
  },
  cs: {
    and: [
      "* ",
      "A tak\xE9 ",
      "A "
    ],
    background: [
      "Pozad\xED",
      "Kontext"
    ],
    but: [
      "* ",
      "Ale "
    ],
    examples: [
      "P\u0159\xEDklady"
    ],
    feature: [
      "Po\u017Eadavek"
    ],
    given: [
      "* ",
      "Pokud ",
      "Za p\u0159edpokladu "
    ],
    name: "Czech",
    native: "\u010Cesky",
    rule: [
      "Pravidlo"
    ],
    scenario: [
      "P\u0159\xEDklad",
      "Sc\xE9n\xE1\u0159"
    ],
    scenarioOutline: [
      "N\xE1\u010Drt Sc\xE9n\xE1\u0159e",
      "Osnova sc\xE9n\xE1\u0159e"
    ],
    then: [
      "* ",
      "Pak "
    ],
    when: [
      "* ",
      "Kdy\u017E "
    ]
  },
  "cy-GB": {
    and: [
      "* ",
      "A "
    ],
    background: [
      "Cefndir"
    ],
    but: [
      "* ",
      "Ond "
    ],
    examples: [
      "Enghreifftiau"
    ],
    feature: [
      "Arwedd"
    ],
    given: [
      "* ",
      "Anrhegedig a "
    ],
    name: "Welsh",
    native: "Cymraeg",
    rule: [
      "Rule"
    ],
    scenario: [
      "Enghraifft",
      "Scenario"
    ],
    scenarioOutline: [
      "Scenario Amlinellol"
    ],
    then: [
      "* ",
      "Yna "
    ],
    when: [
      "* ",
      "Pryd "
    ]
  },
  da: {
    and: [
      "* ",
      "Og "
    ],
    background: [
      "Baggrund"
    ],
    but: [
      "* ",
      "Men "
    ],
    examples: [
      "Eksempler"
    ],
    feature: [
      "Egenskab"
    ],
    given: [
      "* ",
      "Givet "
    ],
    name: "Danish",
    native: "dansk",
    rule: [
      "Regel"
    ],
    scenario: [
      "Eksempel",
      "Scenarie"
    ],
    scenarioOutline: [
      "Abstrakt Scenario"
    ],
    then: [
      "* ",
      "S\xE5 "
    ],
    when: [
      "* ",
      "N\xE5r "
    ]
  },
  de: {
    and: [
      "* ",
      "Und "
    ],
    background: [
      "Grundlage",
      "Hintergrund",
      "Voraussetzungen",
      "Vorbedingungen"
    ],
    but: [
      "* ",
      "Aber "
    ],
    examples: [
      "Beispiele"
    ],
    feature: [
      "Funktionalit\xE4t",
      "Funktion"
    ],
    given: [
      "* ",
      "Angenommen ",
      "Gegeben sei ",
      "Gegeben seien "
    ],
    name: "German",
    native: "Deutsch",
    rule: [
      "Rule",
      "Regel"
    ],
    scenario: [
      "Beispiel",
      "Szenario"
    ],
    scenarioOutline: [
      "Szenariogrundriss",
      "Szenarien"
    ],
    then: [
      "* ",
      "Dann "
    ],
    when: [
      "* ",
      "Wenn "
    ]
  },
  el: {
    and: [
      "* ",
      "\u039A\u03B1\u03B9 "
    ],
    background: [
      "\u03A5\u03C0\u03CC\u03B2\u03B1\u03B8\u03C1\u03BF"
    ],
    but: [
      "* ",
      "\u0391\u03BB\u03BB\u03AC "
    ],
    examples: [
      "\u03A0\u03B1\u03C1\u03B1\u03B4\u03B5\u03AF\u03B3\u03BC\u03B1\u03C4\u03B1",
      "\u03A3\u03B5\u03BD\u03AC\u03C1\u03B9\u03B1"
    ],
    feature: [
      "\u0394\u03C5\u03BD\u03B1\u03C4\u03CC\u03C4\u03B7\u03C4\u03B1",
      "\u039B\u03B5\u03B9\u03C4\u03BF\u03C5\u03C1\u03B3\u03AF\u03B1"
    ],
    given: [
      "* ",
      "\u0394\u03B5\u03B4\u03BF\u03BC\u03AD\u03BD\u03BF\u03C5 "
    ],
    name: "Greek",
    native: "\u0395\u03BB\u03BB\u03B7\u03BD\u03B9\u03BA\u03AC",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u03A0\u03B1\u03C1\u03AC\u03B4\u03B5\u03B9\u03B3\u03BC\u03B1",
      "\u03A3\u03B5\u03BD\u03AC\u03C1\u03B9\u03BF"
    ],
    scenarioOutline: [
      "\u03A0\u03B5\u03C1\u03B9\u03B3\u03C1\u03B1\u03C6\u03AE \u03A3\u03B5\u03BD\u03B1\u03C1\u03AF\u03BF\u03C5",
      "\u03A0\u03B5\u03C1\u03AF\u03B3\u03C1\u03B1\u03BC\u03BC\u03B1 \u03A3\u03B5\u03BD\u03B1\u03C1\u03AF\u03BF\u03C5"
    ],
    then: [
      "* ",
      "\u03A4\u03CC\u03C4\u03B5 "
    ],
    when: [
      "* ",
      "\u038C\u03C4\u03B1\u03BD "
    ]
  },
  em: {
    and: [
      "* ",
      "\u{1F602}"
    ],
    background: [
      "\u{1F4A4}"
    ],
    but: [
      "* ",
      "\u{1F614}"
    ],
    examples: [
      "\u{1F4D3}"
    ],
    feature: [
      "\u{1F4DA}"
    ],
    given: [
      "* ",
      "\u{1F610}"
    ],
    name: "Emoji",
    native: "\u{1F600}",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u{1F952}",
      "\u{1F4D5}"
    ],
    scenarioOutline: [
      "\u{1F4D6}"
    ],
    then: [
      "* ",
      "\u{1F64F}"
    ],
    when: [
      "* ",
      "\u{1F3AC}"
    ]
  },
  en: {
    and: [
      "* ",
      "And "
    ],
    background: [
      "Background"
    ],
    but: [
      "* ",
      "But "
    ],
    examples: [
      "Examples",
      "Scenarios"
    ],
    feature: [
      "Feature",
      "Business Need",
      "Ability"
    ],
    given: [
      "* ",
      "Given "
    ],
    name: "English",
    native: "English",
    rule: [
      "Rule"
    ],
    scenario: [
      "Example",
      "Scenario"
    ],
    scenarioOutline: [
      "Scenario Outline",
      "Scenario Template"
    ],
    then: [
      "* ",
      "Then "
    ],
    when: [
      "* ",
      "When "
    ]
  },
  "en-Scouse": {
    and: [
      "* ",
      "An "
    ],
    background: [
      "Dis is what went down"
    ],
    but: [
      "* ",
      "Buh "
    ],
    examples: [
      "Examples"
    ],
    feature: [
      "Feature"
    ],
    given: [
      "* ",
      "Givun ",
      "Youse know when youse got "
    ],
    name: "Scouse",
    native: "Scouse",
    rule: [
      "Rule"
    ],
    scenario: [
      "The thing of it is"
    ],
    scenarioOutline: [
      "Wharrimean is"
    ],
    then: [
      "* ",
      "Dun ",
      "Den youse gotta "
    ],
    when: [
      "* ",
      "Wun ",
      "Youse know like when "
    ]
  },
  "en-au": {
    and: [
      "* ",
      "Too right "
    ],
    background: [
      "First off"
    ],
    but: [
      "* ",
      "Yeah nah "
    ],
    examples: [
      "You'll wanna"
    ],
    feature: [
      "Pretty much"
    ],
    given: [
      "* ",
      "Y'know "
    ],
    name: "Australian",
    native: "Australian",
    rule: [
      "Rule"
    ],
    scenario: [
      "Awww, look mate"
    ],
    scenarioOutline: [
      "Reckon it's like"
    ],
    then: [
      "* ",
      "But at the end of the day I reckon "
    ],
    when: [
      "* ",
      "It's just unbelievable "
    ]
  },
  "en-lol": {
    and: [
      "* ",
      "AN "
    ],
    background: [
      "B4"
    ],
    but: [
      "* ",
      "BUT "
    ],
    examples: [
      "EXAMPLZ"
    ],
    feature: [
      "OH HAI"
    ],
    given: [
      "* ",
      "I CAN HAZ "
    ],
    name: "LOLCAT",
    native: "LOLCAT",
    rule: [
      "Rule"
    ],
    scenario: [
      "MISHUN"
    ],
    scenarioOutline: [
      "MISHUN SRSLY"
    ],
    then: [
      "* ",
      "DEN "
    ],
    when: [
      "* ",
      "WEN "
    ]
  },
  "en-old": {
    and: [
      "* ",
      "Ond ",
      "7 "
    ],
    background: [
      "Aer",
      "\xC6r"
    ],
    but: [
      "* ",
      "Ac "
    ],
    examples: [
      "Se the",
      "Se \xFEe",
      "Se \xF0e"
    ],
    feature: [
      "Hwaet",
      "Hw\xE6t"
    ],
    given: [
      "* ",
      "Thurh ",
      "\xDEurh ",
      "\xD0urh "
    ],
    name: "Old English",
    native: "Englisc",
    rule: [
      "Rule"
    ],
    scenario: [
      "Swa"
    ],
    scenarioOutline: [
      "Swa hwaer swa",
      "Swa hw\xE6r swa"
    ],
    then: [
      "* ",
      "Tha ",
      "\xDEa ",
      "\xD0a ",
      "Tha the ",
      "\xDEa \xFEe ",
      "\xD0a \xF0e "
    ],
    when: [
      "* ",
      "B\xE6\xFEsealf ",
      "B\xE6\xFEsealfa ",
      "B\xE6\xFEsealfe ",
      "Ciric\xE6w ",
      "Ciric\xE6we ",
      "Ciric\xE6wa "
    ]
  },
  "en-pirate": {
    and: [
      "* ",
      "Aye "
    ],
    background: [
      "Yo-ho-ho"
    ],
    but: [
      "* ",
      "Avast! "
    ],
    examples: [
      "Dead men tell no tales"
    ],
    feature: [
      "Ahoy matey!"
    ],
    given: [
      "* ",
      "Gangway! "
    ],
    name: "Pirate",
    native: "Pirate",
    rule: [
      "Rule"
    ],
    scenario: [
      "Heave to"
    ],
    scenarioOutline: [
      "Shiver me timbers"
    ],
    then: [
      "* ",
      "Let go and haul "
    ],
    when: [
      "* ",
      "Blimey! "
    ]
  },
  "en-tx": {
    and: [
      "Come hell or high water "
    ],
    background: [
      "Lemme tell y'all a story"
    ],
    but: [
      "Well now hold on, I'll you what "
    ],
    examples: [
      "Now that's a story longer than a cattle drive in July"
    ],
    feature: [
      "This ain\u2019t my first rodeo",
      "All gussied up"
    ],
    given: [
      "Fixin' to ",
      "All git out "
    ],
    name: "Texas",
    native: "Texas",
    rule: [
      "Rule "
    ],
    scenario: [
      "All hat and no cattle"
    ],
    scenarioOutline: [
      "Serious as a snake bite",
      "Busy as a hound in flea season"
    ],
    then: [
      "There\u2019s no tree but bears some fruit "
    ],
    when: [
      "Quick out of the chute "
    ]
  },
  eo: {
    and: [
      "* ",
      "Kaj "
    ],
    background: [
      "Fono"
    ],
    but: [
      "* ",
      "Sed "
    ],
    examples: [
      "Ekzemploj"
    ],
    feature: [
      "Trajto"
    ],
    given: [
      "* ",
      "Donita\u0135o ",
      "Komence "
    ],
    name: "Esperanto",
    native: "Esperanto",
    rule: [
      "Regulo"
    ],
    scenario: [
      "Ekzemplo",
      "Scenaro",
      "Kazo"
    ],
    scenarioOutline: [
      "Konturo de la scenaro",
      "Skizo",
      "Kazo-skizo"
    ],
    then: [
      "* ",
      "Do "
    ],
    when: [
      "* ",
      "Se "
    ]
  },
  es: {
    and: [
      "* ",
      "Y ",
      "E "
    ],
    background: [
      "Antecedentes"
    ],
    but: [
      "* ",
      "Pero "
    ],
    examples: [
      "Ejemplos"
    ],
    feature: [
      "Caracter\xEDstica",
      "Necesidad del negocio",
      "Requisito"
    ],
    given: [
      "* ",
      "Dado ",
      "Dada ",
      "Dados ",
      "Dadas "
    ],
    name: "Spanish",
    native: "espa\xF1ol",
    rule: [
      "Regla",
      "Regla de negocio"
    ],
    scenario: [
      "Ejemplo",
      "Escenario"
    ],
    scenarioOutline: [
      "Esquema del escenario"
    ],
    then: [
      "* ",
      "Entonces "
    ],
    when: [
      "* ",
      "Cuando "
    ]
  },
  et: {
    and: [
      "* ",
      "Ja "
    ],
    background: [
      "Taust"
    ],
    but: [
      "* ",
      "Kuid "
    ],
    examples: [
      "Juhtumid"
    ],
    feature: [
      "Omadus"
    ],
    given: [
      "* ",
      "Eeldades "
    ],
    name: "Estonian",
    native: "eesti keel",
    rule: [
      "Reegel"
    ],
    scenario: [
      "Juhtum",
      "Stsenaarium"
    ],
    scenarioOutline: [
      "Raamjuhtum",
      "Raamstsenaarium"
    ],
    then: [
      "* ",
      "Siis "
    ],
    when: [
      "* ",
      "Kui "
    ]
  },
  fa: {
    and: [
      "* ",
      "\u0648 "
    ],
    background: [
      "\u0632\u0645\u06CC\u0646\u0647",
      "\u067E\u06CC\u0634 \u0632\u0645\u06CC\u0646\u0647",
      "\u0645\u0642\u062F\u0645\u0627\u062A"
    ],
    but: [
      "* ",
      "\u0627\u0645\u0627 "
    ],
    examples: [
      "\u0646\u0645\u0648\u0646\u0647 \u0647\u0627"
    ],
    feature: [
      "\u0648\u06CC\u0698\u06AF\u06CC",
      "\u0642\u0627\u0628\u0644\u06CC\u062A"
    ],
    given: [
      "* ",
      "\u0628\u0627 \u0641\u0631\u0636 ",
      "\u0641\u0631\u0636 \u06A9\u0646\u06CC\u062F ",
      "\u0628\u0627 \u062F\u0631 \u0646\u0638\u0631 \u06AF\u0631\u0641\u062A\u0646 "
    ],
    name: "Persian",
    native: "\u0641\u0627\u0631\u0633\u06CC",
    rule: [
      "\u0642\u0627\u0646\u0648\u0646"
    ],
    scenario: [
      "\u0645\u062B\u0627\u0644",
      "\u0633\u0646\u0627\u0631\u06CC\u0648"
    ],
    scenarioOutline: [
      "\u0627\u0644\u06AF\u0648\u06CC \u0633\u0646\u0627\u0631\u06CC\u0648"
    ],
    then: [
      "* ",
      "\u0622\u0646\u06AF\u0627\u0647 ",
      "\u0633\u067E\u0633 ",
      "\u0627\u0646\u062A\u0638\u0627\u0631 \u0645\u06CC \u0631\u0648\u062F "
    ],
    when: [
      "* ",
      "\u0647\u0646\u06AF\u0627\u0645\u06CC ",
      "\u0648\u0642\u062A\u06CC "
    ]
  },
  fi: {
    and: [
      "* ",
      "Ja "
    ],
    background: [
      "Tausta"
    ],
    but: [
      "* ",
      "Mutta "
    ],
    examples: [
      "Tapaukset"
    ],
    feature: [
      "Ominaisuus"
    ],
    given: [
      "* ",
      "Oletetaan "
    ],
    name: "Finnish",
    native: "suomi",
    rule: [
      "Rule"
    ],
    scenario: [
      "Tapaus"
    ],
    scenarioOutline: [
      "Tapausaihio"
    ],
    then: [
      "* ",
      "Niin "
    ],
    when: [
      "* ",
      "Kun "
    ]
  },
  fr: {
    and: [
      "* ",
      "Et que ",
      "Et qu'",
      "Et "
    ],
    background: [
      "Contexte"
    ],
    but: [
      "* ",
      "Mais que ",
      "Mais qu'",
      "Mais "
    ],
    examples: [
      "Exemples"
    ],
    feature: [
      "Fonctionnalit\xE9"
    ],
    given: [
      "* ",
      "Soit ",
      "Sachant que ",
      "Sachant qu'",
      "Sachant ",
      "Etant donn\xE9 que ",
      "Etant donn\xE9 qu'",
      "Etant donn\xE9 ",
      "Etant donn\xE9e ",
      "Etant donn\xE9s ",
      "Etant donn\xE9es ",
      "\xC9tant donn\xE9 que ",
      "\xC9tant donn\xE9 qu'",
      "\xC9tant donn\xE9 ",
      "\xC9tant donn\xE9e ",
      "\xC9tant donn\xE9s ",
      "\xC9tant donn\xE9es "
    ],
    name: "French",
    native: "fran\xE7ais",
    rule: [
      "R\xE8gle"
    ],
    scenario: [
      "Exemple",
      "Sc\xE9nario"
    ],
    scenarioOutline: [
      "Plan du sc\xE9nario",
      "Plan du Sc\xE9nario"
    ],
    then: [
      "* ",
      "Alors ",
      "Donc "
    ],
    when: [
      "* ",
      "Quand ",
      "Lorsque ",
      "Lorsqu'"
    ]
  },
  ga: {
    and: [
      "* ",
      "Agus "
    ],
    background: [
      "C\xFAlra"
    ],
    but: [
      "* ",
      "Ach "
    ],
    examples: [
      "Sampla\xED"
    ],
    feature: [
      "Gn\xE9"
    ],
    given: [
      "* ",
      "Cuir i gc\xE1s go ",
      "Cuir i gc\xE1s nach ",
      "Cuir i gc\xE1s gur ",
      "Cuir i gc\xE1s n\xE1r "
    ],
    name: "Irish",
    native: "Gaeilge",
    rule: [
      "Riail"
    ],
    scenario: [
      "Sampla",
      "C\xE1s"
    ],
    scenarioOutline: [
      "C\xE1s Achomair"
    ],
    then: [
      "* ",
      "Ansin "
    ],
    when: [
      "* ",
      "Nuair a ",
      "Nuair nach ",
      "Nuair ba ",
      "Nuair n\xE1r "
    ]
  },
  gj: {
    and: [
      "* ",
      "\u0A85\u0AA8\u0AC7 "
    ],
    background: [
      "\u0AAC\u0AC7\u0A95\u0A97\u0ACD\u0AB0\u0ABE\u0A89\u0AA8\u0ACD\u0AA1"
    ],
    but: [
      "* ",
      "\u0AAA\u0AA3 "
    ],
    examples: [
      "\u0A89\u0AA6\u0ABE\u0AB9\u0AB0\u0AA3\u0ACB"
    ],
    feature: [
      "\u0AB2\u0A95\u0ACD\u0AB7\u0AA3",
      "\u0AB5\u0ACD\u0AAF\u0ABE\u0AAA\u0ABE\u0AB0 \u0A9C\u0AB0\u0AC2\u0AB0",
      "\u0A95\u0ACD\u0AB7\u0AAE\u0AA4\u0ABE"
    ],
    given: [
      "* ",
      "\u0A86\u0AAA\u0AC7\u0AB2 \u0A9B\u0AC7 "
    ],
    name: "Gujarati",
    native: "\u0A97\u0AC1\u0A9C\u0AB0\u0ABE\u0AA4\u0AC0",
    rule: [
      "\u0AA8\u0ABF\u0AAF\u0AAE"
    ],
    scenario: [
      "\u0A89\u0AA6\u0ABE\u0AB9\u0AB0\u0AA3",
      "\u0AB8\u0ACD\u0AA5\u0ABF\u0AA4\u0ABF"
    ],
    scenarioOutline: [
      "\u0AAA\u0AB0\u0ABF\u0AA6\u0ACD\u0AA6\u0AB6\u0ACD\u0AAF \u0AB0\u0AC2\u0AAA\u0AB0\u0AC7\u0A96\u0ABE",
      "\u0AAA\u0AB0\u0ABF\u0AA6\u0ACD\u0AA6\u0AB6\u0ACD\u0AAF \u0AA2\u0ABE\u0A82\u0A9A\u0ACB"
    ],
    then: [
      "* ",
      "\u0AAA\u0A9B\u0AC0 "
    ],
    when: [
      "* ",
      "\u0A95\u0ACD\u0AAF\u0ABE\u0AB0\u0AC7 "
    ]
  },
  gl: {
    and: [
      "* ",
      "E "
    ],
    background: [
      "Contexto"
    ],
    but: [
      "* ",
      "Mais ",
      "Pero "
    ],
    examples: [
      "Exemplos"
    ],
    feature: [
      "Caracter\xEDstica"
    ],
    given: [
      "* ",
      "Dado ",
      "Dada ",
      "Dados ",
      "Dadas "
    ],
    name: "Galician",
    native: "galego",
    rule: [
      "Rule"
    ],
    scenario: [
      "Exemplo",
      "Escenario"
    ],
    scenarioOutline: [
      "Esbozo do escenario"
    ],
    then: [
      "* ",
      "Ent\xF3n ",
      "Logo "
    ],
    when: [
      "* ",
      "Cando "
    ]
  },
  he: {
    and: [
      "* ",
      "\u05D5\u05D2\u05DD "
    ],
    background: [
      "\u05E8\u05E7\u05E2"
    ],
    but: [
      "* ",
      "\u05D0\u05D1\u05DC "
    ],
    examples: [
      "\u05D3\u05D5\u05D2\u05DE\u05D0\u05D5\u05EA"
    ],
    feature: [
      "\u05EA\u05DB\u05D5\u05E0\u05D4"
    ],
    given: [
      "* ",
      "\u05D1\u05D4\u05D9\u05E0\u05EA\u05DF "
    ],
    name: "Hebrew",
    native: "\u05E2\u05D1\u05E8\u05D9\u05EA",
    rule: [
      "\u05DB\u05DC\u05DC"
    ],
    scenario: [
      "\u05D3\u05D5\u05D2\u05DE\u05D0",
      "\u05EA\u05E8\u05D7\u05D9\u05E9"
    ],
    scenarioOutline: [
      "\u05EA\u05D1\u05E0\u05D9\u05EA \u05EA\u05E8\u05D7\u05D9\u05E9"
    ],
    then: [
      "* ",
      "\u05D0\u05D6 ",
      "\u05D0\u05D6\u05D9 "
    ],
    when: [
      "* ",
      "\u05DB\u05D0\u05E9\u05E8 "
    ]
  },
  hi: {
    and: [
      "* ",
      "\u0914\u0930 ",
      "\u0924\u0925\u093E "
    ],
    background: [
      "\u092A\u0943\u0937\u094D\u0920\u092D\u0942\u092E\u093F"
    ],
    but: [
      "* ",
      "\u092A\u0930 ",
      "\u092A\u0930\u0928\u094D\u0924\u0941 ",
      "\u0915\u093F\u0928\u094D\u0924\u0941 "
    ],
    examples: [
      "\u0909\u0926\u093E\u0939\u0930\u0923"
    ],
    feature: [
      "\u0930\u0942\u092A \u0932\u0947\u0916"
    ],
    given: [
      "* ",
      "\u0905\u0917\u0930 ",
      "\u092F\u0926\u093F ",
      "\u091A\u0942\u0902\u0915\u093F "
    ],
    name: "Hindi",
    native: "\u0939\u093F\u0902\u0926\u0940",
    rule: [
      "\u0928\u093F\u092F\u092E"
    ],
    scenario: [
      "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F"
    ],
    scenarioOutline: [
      "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F \u0930\u0942\u092A\u0930\u0947\u0916\u093E"
    ],
    then: [
      "* ",
      "\u0924\u092C ",
      "\u0924\u0926\u093E "
    ],
    when: [
      "* ",
      "\u091C\u092C ",
      "\u0915\u0926\u093E "
    ]
  },
  hr: {
    and: [
      "* ",
      "I "
    ],
    background: [
      "Pozadina"
    ],
    but: [
      "* ",
      "Ali "
    ],
    examples: [
      "Primjeri",
      "Scenariji"
    ],
    feature: [
      "Osobina",
      "Mogu\u0107nost",
      "Mogucnost"
    ],
    given: [
      "* ",
      "Zadan ",
      "Zadani ",
      "Zadano ",
      "Ukoliko "
    ],
    name: "Croatian",
    native: "hrvatski",
    rule: [
      "Rule"
    ],
    scenario: [
      "Primjer",
      "Scenarij"
    ],
    scenarioOutline: [
      "Skica",
      "Koncept"
    ],
    then: [
      "* ",
      "Onda "
    ],
    when: [
      "* ",
      "Kada ",
      "Kad "
    ]
  },
  ht: {
    and: [
      "* ",
      "Ak ",
      "Epi ",
      "E "
    ],
    background: [
      "Kont\xE8ks",
      "Istorik"
    ],
    but: [
      "* ",
      "Men "
    ],
    examples: [
      "Egzanp"
    ],
    feature: [
      "Karakteristik",
      "Mak",
      "Fonksyonalite"
    ],
    given: [
      "* ",
      "Sipoze ",
      "Sipoze ke ",
      "Sipoze Ke "
    ],
    name: "Creole",
    native: "krey\xF2l",
    rule: [
      "Rule"
    ],
    scenario: [
      "Senaryo"
    ],
    scenarioOutline: [
      "Plan senaryo",
      "Plan Senaryo",
      "Senaryo deskripsyon",
      "Senaryo Deskripsyon",
      "Dyagram senaryo",
      "Dyagram Senaryo"
    ],
    then: [
      "* ",
      "L\xE8 sa a ",
      "Le sa a "
    ],
    when: [
      "* ",
      "L\xE8 ",
      "Le "
    ]
  },
  hu: {
    and: [
      "* ",
      "\xC9s "
    ],
    background: [
      "H\xE1tt\xE9r"
    ],
    but: [
      "* ",
      "De "
    ],
    examples: [
      "P\xE9ld\xE1k"
    ],
    feature: [
      "Jellemz\u0151"
    ],
    given: [
      "* ",
      "Amennyiben ",
      "Adott "
    ],
    name: "Hungarian",
    native: "magyar",
    rule: [
      "Szab\xE1ly"
    ],
    scenario: [
      "P\xE9lda",
      "Forgat\xF3k\xF6nyv"
    ],
    scenarioOutline: [
      "Forgat\xF3k\xF6nyv v\xE1zlat"
    ],
    then: [
      "* ",
      "Akkor "
    ],
    when: [
      "* ",
      "Majd ",
      "Ha ",
      "Amikor "
    ]
  },
  id: {
    and: [
      "* ",
      "Dan "
    ],
    background: [
      "Dasar",
      "Latar Belakang"
    ],
    but: [
      "* ",
      "Tapi ",
      "Tetapi "
    ],
    examples: [
      "Contoh",
      "Misal"
    ],
    feature: [
      "Fitur"
    ],
    given: [
      "* ",
      "Dengan ",
      "Diketahui ",
      "Diasumsikan ",
      "Bila ",
      "Jika "
    ],
    name: "Indonesian",
    native: "Bahasa Indonesia",
    rule: [
      "Rule",
      "Aturan"
    ],
    scenario: [
      "Skenario"
    ],
    scenarioOutline: [
      "Skenario konsep",
      "Garis-Besar Skenario"
    ],
    then: [
      "* ",
      "Maka ",
      "Kemudian "
    ],
    when: [
      "* ",
      "Ketika "
    ]
  },
  is: {
    and: [
      "* ",
      "Og "
    ],
    background: [
      "Bakgrunnur"
    ],
    but: [
      "* ",
      "En "
    ],
    examples: [
      "D\xE6mi",
      "Atbur\xF0ar\xE1sir"
    ],
    feature: [
      "Eiginleiki"
    ],
    given: [
      "* ",
      "Ef "
    ],
    name: "Icelandic",
    native: "\xCDslenska",
    rule: [
      "Rule"
    ],
    scenario: [
      "Atbur\xF0ar\xE1s"
    ],
    scenarioOutline: [
      "L\xFDsing Atbur\xF0ar\xE1sar",
      "L\xFDsing D\xE6ma"
    ],
    then: [
      "* ",
      "\xDE\xE1 "
    ],
    when: [
      "* ",
      "\xDEegar "
    ]
  },
  it: {
    and: [
      "* ",
      "E ",
      "Ed "
    ],
    background: [
      "Contesto"
    ],
    but: [
      "* ",
      "Ma "
    ],
    examples: [
      "Esempi"
    ],
    feature: [
      "Funzionalit\xE0",
      "Esigenza di Business",
      "Abilit\xE0"
    ],
    given: [
      "* ",
      "Dato ",
      "Data ",
      "Dati ",
      "Date "
    ],
    name: "Italian",
    native: "italiano",
    rule: [
      "Regola"
    ],
    scenario: [
      "Esempio",
      "Scenario"
    ],
    scenarioOutline: [
      "Schema dello scenario"
    ],
    then: [
      "* ",
      "Allora "
    ],
    when: [
      "* ",
      "Quando "
    ]
  },
  ja: {
    and: [
      "* ",
      "\u4E14\u3064",
      "\u304B\u3064"
    ],
    background: [
      "\u80CC\u666F"
    ],
    but: [
      "* ",
      "\u7136\u3057",
      "\u3057\u304B\u3057",
      "\u4F46\u3057",
      "\u305F\u3060\u3057"
    ],
    examples: [
      "\u4F8B",
      "\u30B5\u30F3\u30D7\u30EB"
    ],
    feature: [
      "\u30D5\u30A3\u30FC\u30C1\u30E3",
      "\u6A5F\u80FD"
    ],
    given: [
      "* ",
      "\u524D\u63D0"
    ],
    name: "Japanese",
    native: "\u65E5\u672C\u8A9E",
    rule: [
      "\u30EB\u30FC\u30EB"
    ],
    scenario: [
      "\u30B7\u30CA\u30EA\u30AA"
    ],
    scenarioOutline: [
      "\u30B7\u30CA\u30EA\u30AA\u30A2\u30A6\u30C8\u30E9\u30A4\u30F3",
      "\u30B7\u30CA\u30EA\u30AA\u30C6\u30F3\u30D7\u30EC\u30FC\u30C8",
      "\u30C6\u30F3\u30D7\u30EC",
      "\u30B7\u30CA\u30EA\u30AA\u30C6\u30F3\u30D7\u30EC"
    ],
    then: [
      "* ",
      "\u306A\u3089\u3070"
    ],
    when: [
      "* ",
      "\u3082\u3057"
    ]
  },
  jv: {
    and: [
      "* ",
      "Lan "
    ],
    background: [
      "Dasar"
    ],
    but: [
      "* ",
      "Tapi ",
      "Nanging ",
      "Ananging "
    ],
    examples: [
      "Conto",
      "Contone"
    ],
    feature: [
      "Fitur"
    ],
    given: [
      "* ",
      "Nalika ",
      "Nalikaning "
    ],
    name: "Javanese",
    native: "Basa Jawa",
    rule: [
      "Rule"
    ],
    scenario: [
      "Skenario"
    ],
    scenarioOutline: [
      "Konsep skenario"
    ],
    then: [
      "* ",
      "Njuk ",
      "Banjur "
    ],
    when: [
      "* ",
      "Manawa ",
      "Menawa "
    ]
  },
  ka: {
    and: [
      "* ",
      "\u10D3\u10D0 ",
      "\u10D0\u10E1\u10D4\u10D5\u10D4 "
    ],
    background: [
      "\u10D9\u10DD\u10DC\u10E2\u10D4\u10E5\u10E1\u10E2\u10D8"
    ],
    but: [
      "* ",
      "\u10DB\u10D0\u10D2\u10E0\u10D0\u10DB ",
      "\u10D7\u10E3\u10DB\u10EA\u10D0 "
    ],
    examples: [
      "\u10DB\u10D0\u10D2\u10D0\u10DA\u10D8\u10D7\u10D4\u10D1\u10D8"
    ],
    feature: [
      "\u10D7\u10D5\u10D8\u10E1\u10D4\u10D1\u10D0",
      "\u10DB\u10DD\u10D7\u10EE\u10DD\u10D5\u10DC\u10D0"
    ],
    given: [
      "* ",
      "\u10DB\u10DD\u10EA\u10D4\u10DB\u10E3\u10DA\u10D8 ",
      "\u10DB\u10DD\u10EA\u10D4\u10DB\u10E3\u10DA\u10D8\u10D0 ",
      "\u10D5\u10D7\u10E5\u10D5\u10D0\u10D7 "
    ],
    name: "Georgian",
    native: "\u10E5\u10D0\u10E0\u10D7\u10E3\u10DA\u10D8",
    rule: [
      "\u10EC\u10D4\u10E1\u10D8"
    ],
    scenario: [
      "\u10DB\u10D0\u10D2\u10D0\u10DA\u10D8\u10D7\u10D0\u10D3",
      "\u10DB\u10D0\u10D2\u10D0\u10DA\u10D8\u10D7\u10D8",
      "\u10DB\u10D0\u10D2",
      "\u10E1\u10EA\u10D4\u10DC\u10D0\u10E0\u10D8"
    ],
    scenarioOutline: [
      "\u10E1\u10EA\u10D4\u10DC\u10D0\u10E0\u10D8\u10E1 \u10DC\u10D8\u10DB\u10E3\u10E8\u10D8",
      "\u10E1\u10EA\u10D4\u10DC\u10D0\u10E0\u10D8\u10E1 \u10E8\u10D0\u10D1\u10DA\u10DD\u10DC\u10D8",
      "\u10DC\u10D8\u10DB\u10E3\u10E8\u10D8",
      "\u10E8\u10D0\u10D1\u10DA\u10DD\u10DC\u10D8"
    ],
    then: [
      "* ",
      "\u10DB\u10D0\u10E8\u10D8\u10DC "
    ],
    when: [
      "* ",
      "\u10E0\u10DD\u10D3\u10D4\u10E1\u10D0\u10EA ",
      "\u10E0\u10DD\u10EA\u10D0 ",
      "\u10E0\u10DD\u10D2\u10DD\u10E0\u10EA \u10D9\u10D8 ",
      "\u10D7\u10E3 "
    ]
  },
  kn: {
    and: [
      "* ",
      "\u0CAE\u0CA4\u0CCD\u0CA4\u0CC1 "
    ],
    background: [
      "\u0CB9\u0CBF\u0CA8\u0CCD\u0CA8\u0CC6\u0CB2\u0CC6"
    ],
    but: [
      "* ",
      "\u0C86\u0CA6\u0CB0\u0CC6 "
    ],
    examples: [
      "\u0C89\u0CA6\u0CBE\u0CB9\u0CB0\u0CA3\u0CC6\u0C97\u0CB3\u0CC1"
    ],
    feature: [
      "\u0CB9\u0CC6\u0C9A\u0CCD\u0C9A\u0CB3"
    ],
    given: [
      "* ",
      "\u0CA8\u0CBF\u0CD5\u0CA1\u0CBF\u0CA6 "
    ],
    name: "Kannada",
    native: "\u0C95\u0CA8\u0CCD\u0CA8\u0CA1",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0C89\u0CA6\u0CBE\u0CB9\u0CB0\u0CA3\u0CC6",
      "\u0C95\u0CA5\u0CBE\u0CB8\u0CBE\u0CB0\u0CBE\u0C82\u0CB6"
    ],
    scenarioOutline: [
      "\u0CB5\u0CBF\u0CB5\u0CB0\u0CA3\u0CC6"
    ],
    then: [
      "* ",
      "\u0CA8\u0C82\u0CA4\u0CB0 "
    ],
    when: [
      "* ",
      "\u0CB8\u0CCD\u0CA5\u0CBF\u0CA4\u0CBF\u0CAF\u0CA8\u0CCD\u0CA8\u0CC1 "
    ]
  },
  ko: {
    and: [
      "* ",
      "\uADF8\uB9AC\uACE0 "
    ],
    background: [
      "\uBC30\uACBD"
    ],
    but: [
      "* ",
      "\uD558\uC9C0\uB9CC ",
      "\uB2E8 "
    ],
    examples: [
      "\uC608"
    ],
    feature: [
      "\uAE30\uB2A5"
    ],
    given: [
      "* ",
      "\uC870\uAC74 ",
      "\uBA3C\uC800 "
    ],
    name: "Korean",
    native: "\uD55C\uAD6D\uC5B4",
    rule: [
      "\uADDC\uCE59"
    ],
    scenario: [
      "\uC2DC\uB098\uB9AC\uC624"
    ],
    scenarioOutline: [
      "\uC2DC\uB098\uB9AC\uC624 \uAC1C\uC694"
    ],
    then: [
      "* ",
      "\uADF8\uB7EC\uBA74 "
    ],
    when: [
      "* ",
      "\uB9CC\uC77C ",
      "\uB9CC\uC57D "
    ]
  },
  lt: {
    and: [
      "* ",
      "Ir "
    ],
    background: [
      "Kontekstas"
    ],
    but: [
      "* ",
      "Bet "
    ],
    examples: [
      "Pavyzd\u017Eiai",
      "Scenarijai",
      "Variantai"
    ],
    feature: [
      "Savyb\u0117"
    ],
    given: [
      "* ",
      "Duota "
    ],
    name: "Lithuanian",
    native: "lietuvi\u0173 kalba",
    rule: [
      "Rule"
    ],
    scenario: [
      "Pavyzdys",
      "Scenarijus"
    ],
    scenarioOutline: [
      "Scenarijaus \u0161ablonas"
    ],
    then: [
      "* ",
      "Tada "
    ],
    when: [
      "* ",
      "Kai "
    ]
  },
  lu: {
    and: [
      "* ",
      "an ",
      "a "
    ],
    background: [
      "Hannergrond"
    ],
    but: [
      "* ",
      "awer ",
      "m\xE4 "
    ],
    examples: [
      "Beispiller"
    ],
    feature: [
      "Funktionalit\xE9it"
    ],
    given: [
      "* ",
      "ugeholl "
    ],
    name: "Luxemburgish",
    native: "L\xEBtzebuergesch",
    rule: [
      "Rule"
    ],
    scenario: [
      "Beispill",
      "Szenario"
    ],
    scenarioOutline: [
      "Plang vum Szenario"
    ],
    then: [
      "* ",
      "dann "
    ],
    when: [
      "* ",
      "wann "
    ]
  },
  lv: {
    and: [
      "* ",
      "Un "
    ],
    background: [
      "Konteksts",
      "Situ\u0101cija"
    ],
    but: [
      "* ",
      "Bet "
    ],
    examples: [
      "Piem\u0113ri",
      "Paraugs"
    ],
    feature: [
      "Funkcionalit\u0101te",
      "F\u012B\u010Da"
    ],
    given: [
      "* ",
      "Kad "
    ],
    name: "Latvian",
    native: "latvie\u0161u",
    rule: [
      "Rule"
    ],
    scenario: [
      "Piem\u0113rs",
      "Scen\u0101rijs"
    ],
    scenarioOutline: [
      "Scen\u0101rijs p\u0113c parauga"
    ],
    then: [
      "* ",
      "Tad "
    ],
    when: [
      "* ",
      "Ja "
    ]
  },
  "mk-Cyrl": {
    and: [
      "* ",
      "\u0418 "
    ],
    background: [
      "\u041A\u043E\u043D\u0442\u0435\u043A\u0441\u0442",
      "\u0421\u043E\u0434\u0440\u0436\u0438\u043D\u0430"
    ],
    but: [
      "* ",
      "\u041D\u043E "
    ],
    examples: [
      "\u041F\u0440\u0438\u043C\u0435\u0440\u0438",
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0458\u0430"
    ],
    feature: [
      "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B\u043D\u043E\u0441\u0442",
      "\u0411\u0438\u0437\u043D\u0438\u0441 \u043F\u043E\u0442\u0440\u0435\u0431\u0430",
      "\u041C\u043E\u0436\u043D\u043E\u0441\u0442"
    ],
    given: [
      "* ",
      "\u0414\u0430\u0434\u0435\u043D\u043E ",
      "\u0414\u0430\u0434\u0435\u043D\u0430 "
    ],
    name: "Macedonian",
    native: "\u041C\u0430\u043A\u0435\u0434\u043E\u043D\u0441\u043A\u0438",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u041F\u0440\u0438\u043C\u0435\u0440",
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u043E",
      "\u041D\u0430 \u043F\u0440\u0438\u043C\u0435\u0440"
    ],
    scenarioOutline: [
      "\u041F\u0440\u0435\u0433\u043B\u0435\u0434 \u043D\u0430 \u0441\u0446\u0435\u043D\u0430\u0440\u0438\u0458\u0430",
      "\u0421\u043A\u0438\u0446\u0430",
      "\u041A\u043E\u043D\u0446\u0435\u043F\u0442"
    ],
    then: [
      "* ",
      "\u0422\u043E\u0433\u0430\u0448 "
    ],
    when: [
      "* ",
      "\u041A\u043E\u0433\u0430 "
    ]
  },
  "mk-Latn": {
    and: [
      "* ",
      "I "
    ],
    background: [
      "Kontekst",
      "Sodrzhina"
    ],
    but: [
      "* ",
      "No "
    ],
    examples: [
      "Primeri",
      "Scenaria"
    ],
    feature: [
      "Funkcionalnost",
      "Biznis potreba",
      "Mozhnost"
    ],
    given: [
      "* ",
      "Dadeno ",
      "Dadena "
    ],
    name: "Macedonian (Latin)",
    native: "Makedonski (Latinica)",
    rule: [
      "Rule"
    ],
    scenario: [
      "Scenario",
      "Na primer"
    ],
    scenarioOutline: [
      "Pregled na scenarija",
      "Skica",
      "Koncept"
    ],
    then: [
      "* ",
      "Togash "
    ],
    when: [
      "* ",
      "Koga "
    ]
  },
  mn: {
    and: [
      "* ",
      "\u041C\u04E9\u043D ",
      "\u0422\u044D\u0433\u044D\u044D\u0434 "
    ],
    background: [
      "\u0410\u0433\u0443\u0443\u043B\u0433\u0430"
    ],
    but: [
      "* ",
      "\u0413\u044D\u0445\u0434\u044D\u044D ",
      "\u0425\u0430\u0440\u0438\u043D "
    ],
    examples: [
      "\u0422\u0443\u0445\u0430\u0439\u043B\u0431\u0430\u043B"
    ],
    feature: [
      "\u0424\u0443\u043D\u043A\u0446",
      "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B"
    ],
    given: [
      "* ",
      "\u04E8\u0433\u04E9\u0433\u0434\u0441\u04E9\u043D \u043D\u044C ",
      "\u0410\u043D\u0445 "
    ],
    name: "Mongolian",
    native: "\u043C\u043E\u043D\u0433\u043E\u043B",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0421\u0446\u0435\u043D\u0430\u0440"
    ],
    scenarioOutline: [
      "\u0421\u0446\u0435\u043D\u0430\u0440\u044B\u043D \u0442\u04E9\u043B\u04E9\u0432\u043B\u04E9\u0433\u04E9\u04E9"
    ],
    then: [
      "* ",
      "\u0422\u044D\u0433\u044D\u0445\u044D\u0434 ",
      "\u04AE\u04AF\u043D\u0438\u0439 \u0434\u0430\u0440\u0430\u0430 "
    ],
    when: [
      "* ",
      "\u0425\u044D\u0440\u044D\u0432 "
    ]
  },
  ne: {
    and: [
      "* ",
      "\u0930 ",
      "\u0905\u0928\u093F "
    ],
    background: [
      "\u092A\u0943\u0937\u094D\u0920\u092D\u0942\u092E\u0940"
    ],
    but: [
      "* ",
      "\u0924\u0930 "
    ],
    examples: [
      "\u0909\u0926\u093E\u0939\u0930\u0923",
      "\u0909\u0926\u093E\u0939\u0930\u0923\u0939\u0930\u0941"
    ],
    feature: [
      "\u0938\u0941\u0935\u093F\u0927\u093E",
      "\u0935\u093F\u0936\u0947\u0937\u0924\u093E"
    ],
    given: [
      "* ",
      "\u0926\u093F\u0907\u090F\u0915\u094B ",
      "\u0926\u093F\u090F\u0915\u094B ",
      "\u092F\u0926\u093F "
    ],
    name: "Nepali",
    native: "\u0928\u0947\u092A\u093E\u0932\u0940",
    rule: [
      "\u0928\u093F\u092F\u092E"
    ],
    scenario: [
      "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F"
    ],
    scenarioOutline: [
      "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F \u0930\u0942\u092A\u0930\u0947\u0916\u093E"
    ],
    then: [
      "* ",
      "\u0924\u094D\u092F\u0938\u092A\u091B\u093F ",
      "\u0905\u0928\u0940 "
    ],
    when: [
      "* ",
      "\u091C\u092C "
    ]
  },
  nl: {
    and: [
      "* ",
      "En "
    ],
    background: [
      "Achtergrond"
    ],
    but: [
      "* ",
      "Maar "
    ],
    examples: [
      "Voorbeelden"
    ],
    feature: [
      "Functionaliteit"
    ],
    given: [
      "* ",
      "Gegeven ",
      "Stel "
    ],
    name: "Dutch",
    native: "Nederlands",
    rule: [
      "Regel"
    ],
    scenario: [
      "Voorbeeld",
      "Scenario"
    ],
    scenarioOutline: [
      "Abstract Scenario"
    ],
    then: [
      "* ",
      "Dan "
    ],
    when: [
      "* ",
      "Als ",
      "Wanneer "
    ]
  },
  no: {
    and: [
      "* ",
      "Og "
    ],
    background: [
      "Bakgrunn"
    ],
    but: [
      "* ",
      "Men "
    ],
    examples: [
      "Eksempler"
    ],
    feature: [
      "Egenskap"
    ],
    given: [
      "* ",
      "Gitt "
    ],
    name: "Norwegian",
    native: "norsk",
    rule: [
      "Regel"
    ],
    scenario: [
      "Eksempel",
      "Scenario"
    ],
    scenarioOutline: [
      "Scenariomal",
      "Abstrakt Scenario"
    ],
    then: [
      "* ",
      "S\xE5 "
    ],
    when: [
      "* ",
      "N\xE5r "
    ]
  },
  pa: {
    and: [
      "* ",
      "\u0A05\u0A24\u0A47 "
    ],
    background: [
      "\u0A2A\u0A3F\u0A1B\u0A4B\u0A15\u0A5C"
    ],
    but: [
      "* ",
      "\u0A2A\u0A30 "
    ],
    examples: [
      "\u0A09\u0A26\u0A3E\u0A39\u0A30\u0A28\u0A3E\u0A02"
    ],
    feature: [
      "\u0A16\u0A3E\u0A38\u0A40\u0A05\u0A24",
      "\u0A2E\u0A41\u0A39\u0A3E\u0A02\u0A26\u0A30\u0A3E",
      "\u0A28\u0A15\u0A36 \u0A28\u0A41\u0A39\u0A3E\u0A30"
    ],
    given: [
      "* ",
      "\u0A1C\u0A47\u0A15\u0A30 ",
      "\u0A1C\u0A3F\u0A35\u0A47\u0A02 \u0A15\u0A3F "
    ],
    name: "Panjabi",
    native: "\u0A2A\u0A70\u0A1C\u0A3E\u0A2C\u0A40",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0A09\u0A26\u0A3E\u0A39\u0A30\u0A28",
      "\u0A2A\u0A1F\u0A15\u0A25\u0A3E"
    ],
    scenarioOutline: [
      "\u0A2A\u0A1F\u0A15\u0A25\u0A3E \u0A22\u0A3E\u0A02\u0A1A\u0A3E",
      "\u0A2A\u0A1F\u0A15\u0A25\u0A3E \u0A30\u0A42\u0A2A \u0A30\u0A47\u0A16\u0A3E"
    ],
    then: [
      "* ",
      "\u0A24\u0A26 "
    ],
    when: [
      "* ",
      "\u0A1C\u0A26\u0A4B\u0A02 "
    ]
  },
  pl: {
    and: [
      "* ",
      "Oraz ",
      "I "
    ],
    background: [
      "Za\u0142o\u017Cenia"
    ],
    but: [
      "* ",
      "Ale "
    ],
    examples: [
      "Przyk\u0142ady"
    ],
    feature: [
      "W\u0142a\u015Bciwo\u015B\u0107",
      "Funkcja",
      "Aspekt",
      "Potrzeba biznesowa"
    ],
    given: [
      "* ",
      "Zak\u0142adaj\u0105c ",
      "Maj\u0105c ",
      "Zak\u0142adaj\u0105c, \u017Ce "
    ],
    name: "Polish",
    native: "polski",
    rule: [
      "Zasada",
      "Regu\u0142a"
    ],
    scenario: [
      "Przyk\u0142ad",
      "Scenariusz"
    ],
    scenarioOutline: [
      "Szablon scenariusza"
    ],
    then: [
      "* ",
      "Wtedy "
    ],
    when: [
      "* ",
      "Je\u017Celi ",
      "Je\u015Bli ",
      "Gdy ",
      "Kiedy "
    ]
  },
  pt: {
    and: [
      "* ",
      "E "
    ],
    background: [
      "Contexto",
      "Cen\xE1rio de Fundo",
      "Cenario de Fundo",
      "Fundo"
    ],
    but: [
      "* ",
      "Mas "
    ],
    examples: [
      "Exemplos",
      "Cen\xE1rios",
      "Cenarios"
    ],
    feature: [
      "Funcionalidade",
      "Caracter\xEDstica",
      "Caracteristica"
    ],
    given: [
      "* ",
      "Dado ",
      "Dada ",
      "Dados ",
      "Dadas "
    ],
    name: "Portuguese",
    native: "portugu\xEAs",
    rule: [
      "Regra"
    ],
    scenario: [
      "Exemplo",
      "Cen\xE1rio",
      "Cenario"
    ],
    scenarioOutline: [
      "Esquema do Cen\xE1rio",
      "Esquema do Cenario",
      "Delinea\xE7\xE3o do Cen\xE1rio",
      "Delineacao do Cenario"
    ],
    then: [
      "* ",
      "Ent\xE3o ",
      "Entao "
    ],
    when: [
      "* ",
      "Quando "
    ]
  },
  ro: {
    and: [
      "* ",
      "Si ",
      "\u0218i ",
      "\u015Ei "
    ],
    background: [
      "Context"
    ],
    but: [
      "* ",
      "Dar "
    ],
    examples: [
      "Exemple"
    ],
    feature: [
      "Functionalitate",
      "Func\u021Bionalitate",
      "Func\u0163ionalitate"
    ],
    given: [
      "* ",
      "Date fiind ",
      "Dat fiind ",
      "Dat\u0103 fiind",
      "Dati fiind ",
      "Da\u021Bi fiind ",
      "Da\u0163i fiind "
    ],
    name: "Romanian",
    native: "rom\xE2n\u0103",
    rule: [
      "Rule"
    ],
    scenario: [
      "Exemplu",
      "Scenariu"
    ],
    scenarioOutline: [
      "Structura scenariu",
      "Structur\u0103 scenariu"
    ],
    then: [
      "* ",
      "Atunci "
    ],
    when: [
      "* ",
      "Cand ",
      "C\xE2nd "
    ]
  },
  ru: {
    and: [
      "* ",
      "\u0418 ",
      "\u041A \u0442\u043E\u043C\u0443 \u0436\u0435 ",
      "\u0422\u0430\u043A\u0436\u0435 "
    ],
    background: [
      "\u041F\u0440\u0435\u0434\u044B\u0441\u0442\u043E\u0440\u0438\u044F",
      "\u041A\u043E\u043D\u0442\u0435\u043A\u0441\u0442"
    ],
    but: [
      "* ",
      "\u041D\u043E ",
      "\u0410 ",
      "\u0418\u043D\u0430\u0447\u0435 "
    ],
    examples: [
      "\u041F\u0440\u0438\u043C\u0435\u0440\u044B",
      "\u0417\u043D\u0430\u0447\u0435\u043D\u0438\u044F"
    ],
    feature: [
      "\u0424\u0443\u043D\u043A\u0446\u0438\u044F",
      "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B\u044C\u043D\u043E\u0441\u0442\u044C",
      "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B",
      "\u0421\u0432\u043E\u0439\u0441\u0442\u0432\u043E",
      "\u0424\u0438\u0447\u0430"
    ],
    given: [
      "* ",
      "\u0414\u043E\u043F\u0443\u0441\u0442\u0438\u043C ",
      "\u0414\u0430\u043D\u043E ",
      "\u041F\u0443\u0441\u0442\u044C "
    ],
    name: "Russian",
    native: "\u0440\u0443\u0441\u0441\u043A\u0438\u0439",
    rule: [
      "\u041F\u0440\u0430\u0432\u0438\u043B\u043E"
    ],
    scenario: [
      "\u041F\u0440\u0438\u043C\u0435\u0440",
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439"
    ],
    scenarioOutline: [
      "\u0421\u0442\u0440\u0443\u043A\u0442\u0443\u0440\u0430 \u0441\u0446\u0435\u043D\u0430\u0440\u0438\u044F",
      "\u0428\u0430\u0431\u043B\u043E\u043D \u0441\u0446\u0435\u043D\u0430\u0440\u0438\u044F"
    ],
    then: [
      "* ",
      "\u0422\u043E ",
      "\u0417\u0430\u0442\u0435\u043C ",
      "\u0422\u043E\u0433\u0434\u0430 "
    ],
    when: [
      "* ",
      "\u041A\u043E\u0433\u0434\u0430 ",
      "\u0415\u0441\u043B\u0438 "
    ]
  },
  sk: {
    and: [
      "* ",
      "A ",
      "A tie\u017E ",
      "A taktie\u017E ",
      "A z\xE1rove\u0148 "
    ],
    background: [
      "Pozadie"
    ],
    but: [
      "* ",
      "Ale "
    ],
    examples: [
      "Pr\xEDklady"
    ],
    feature: [
      "Po\u017Eiadavka",
      "Funkcia",
      "Vlastnos\u0165"
    ],
    given: [
      "* ",
      "Pokia\u013E ",
      "Za predpokladu "
    ],
    name: "Slovak",
    native: "Slovensky",
    rule: [
      "Rule"
    ],
    scenario: [
      "Pr\xEDklad",
      "Scen\xE1r"
    ],
    scenarioOutline: [
      "N\xE1\u010Drt Scen\xE1ru",
      "N\xE1\u010Drt Scen\xE1ra",
      "Osnova Scen\xE1ra"
    ],
    then: [
      "* ",
      "Tak ",
      "Potom "
    ],
    when: [
      "* ",
      "Ke\u010F ",
      "Ak "
    ]
  },
  sl: {
    and: [
      "In ",
      "Ter "
    ],
    background: [
      "Kontekst",
      "Osnova",
      "Ozadje"
    ],
    but: [
      "Toda ",
      "Ampak ",
      "Vendar "
    ],
    examples: [
      "Primeri",
      "Scenariji"
    ],
    feature: [
      "Funkcionalnost",
      "Funkcija",
      "Mo\u017Enosti",
      "Moznosti",
      "Lastnost",
      "Zna\u010Dilnost"
    ],
    given: [
      "Dano ",
      "Podano ",
      "Zaradi ",
      "Privzeto "
    ],
    name: "Slovenian",
    native: "Slovenski",
    rule: [
      "Rule"
    ],
    scenario: [
      "Primer",
      "Scenarij"
    ],
    scenarioOutline: [
      "Struktura scenarija",
      "Skica",
      "Koncept",
      "Oris scenarija",
      "Osnutek"
    ],
    then: [
      "Nato ",
      "Potem ",
      "Takrat "
    ],
    when: [
      "Ko ",
      "Ce ",
      "\u010Ce ",
      "Kadar "
    ]
  },
  "sr-Cyrl": {
    and: [
      "* ",
      "\u0418 "
    ],
    background: [
      "\u041A\u043E\u043D\u0442\u0435\u043A\u0441\u0442",
      "\u041E\u0441\u043D\u043E\u0432\u0430",
      "\u041F\u043E\u0437\u0430\u0434\u0438\u043D\u0430"
    ],
    but: [
      "* ",
      "\u0410\u043B\u0438 "
    ],
    examples: [
      "\u041F\u0440\u0438\u043C\u0435\u0440\u0438",
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0458\u0438"
    ],
    feature: [
      "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B\u043D\u043E\u0441\u0442",
      "\u041C\u043E\u0433\u0443\u045B\u043D\u043E\u0441\u0442",
      "\u041E\u0441\u043E\u0431\u0438\u043D\u0430"
    ],
    given: [
      "* ",
      "\u0417\u0430 \u0434\u0430\u0442\u043E ",
      "\u0417\u0430 \u0434\u0430\u0442\u0435 ",
      "\u0417\u0430 \u0434\u0430\u0442\u0438 "
    ],
    name: "Serbian",
    native: "\u0421\u0440\u043F\u0441\u043A\u0438",
    rule: [
      "\u041F\u0440\u0430\u0432\u0438\u043B\u043E"
    ],
    scenario: [
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u043E",
      "\u041F\u0440\u0438\u043C\u0435\u0440"
    ],
    scenarioOutline: [
      "\u0421\u0442\u0440\u0443\u043A\u0442\u0443\u0440\u0430 \u0441\u0446\u0435\u043D\u0430\u0440\u0438\u0458\u0430",
      "\u0421\u043A\u0438\u0446\u0430",
      "\u041A\u043E\u043D\u0446\u0435\u043F\u0442"
    ],
    then: [
      "* ",
      "\u041E\u043D\u0434\u0430 "
    ],
    when: [
      "* ",
      "\u041A\u0430\u0434\u0430 ",
      "\u041A\u0430\u0434 "
    ]
  },
  "sr-Latn": {
    and: [
      "* ",
      "I "
    ],
    background: [
      "Kontekst",
      "Osnova",
      "Pozadina"
    ],
    but: [
      "* ",
      "Ali "
    ],
    examples: [
      "Primeri",
      "Scenariji"
    ],
    feature: [
      "Funkcionalnost",
      "Mogu\u0107nost",
      "Mogucnost",
      "Osobina"
    ],
    given: [
      "* ",
      "Za dato ",
      "Za date ",
      "Za dati "
    ],
    name: "Serbian (Latin)",
    native: "Srpski (Latinica)",
    rule: [
      "Pravilo"
    ],
    scenario: [
      "Scenario",
      "Primer"
    ],
    scenarioOutline: [
      "Struktura scenarija",
      "Skica",
      "Koncept"
    ],
    then: [
      "* ",
      "Onda "
    ],
    when: [
      "* ",
      "Kada ",
      "Kad "
    ]
  },
  sv: {
    and: [
      "* ",
      "Och "
    ],
    background: [
      "Bakgrund"
    ],
    but: [
      "* ",
      "Men "
    ],
    examples: [
      "Exempel"
    ],
    feature: [
      "Egenskap"
    ],
    given: [
      "* ",
      "Givet "
    ],
    name: "Swedish",
    native: "Svenska",
    rule: [
      "Regel"
    ],
    scenario: [
      "Scenario"
    ],
    scenarioOutline: [
      "Abstrakt Scenario",
      "Scenariomall"
    ],
    then: [
      "* ",
      "S\xE5 "
    ],
    when: [
      "* ",
      "N\xE4r "
    ]
  },
  ta: {
    and: [
      "* ",
      "\u0BAE\u0BC7\u0BB2\u0BC1\u0BAE\u0BCD ",
      "\u0BAE\u0BB1\u0BCD\u0BB1\u0BC1\u0BAE\u0BCD "
    ],
    background: [
      "\u0BAA\u0BBF\u0BA9\u0BCD\u0BA9\u0BA3\u0BBF"
    ],
    but: [
      "* ",
      "\u0B86\u0BA9\u0BBE\u0BB2\u0BCD "
    ],
    examples: [
      "\u0B8E\u0B9F\u0BC1\u0BA4\u0BCD\u0BA4\u0BC1\u0B95\u0BCD\u0B95\u0BBE\u0B9F\u0BCD\u0B9F\u0BC1\u0B95\u0BB3\u0BCD",
      "\u0B95\u0BBE\u0B9F\u0BCD\u0B9A\u0BBF\u0B95\u0BB3\u0BCD",
      "\u0BA8\u0BBF\u0BB2\u0BC8\u0BAE\u0BC8\u0B95\u0BB3\u0BBF\u0BB2\u0BCD"
    ],
    feature: [
      "\u0B85\u0BAE\u0BCD\u0B9A\u0BAE\u0BCD",
      "\u0BB5\u0BA3\u0BBF\u0B95 \u0BA4\u0BC7\u0BB5\u0BC8",
      "\u0BA4\u0BBF\u0BB1\u0BA9\u0BCD"
    ],
    given: [
      "* ",
      "\u0B95\u0BC6\u0BBE\u0B9F\u0BC1\u0B95\u0BCD\u0B95\u0BAA\u0BCD\u0BAA\u0B9F\u0BCD\u0B9F "
    ],
    name: "Tamil",
    native: "\u0BA4\u0BAE\u0BBF\u0BB4\u0BCD",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0B89\u0BA4\u0BBE\u0BB0\u0BA3\u0BAE\u0BBE\u0B95",
      "\u0B95\u0BBE\u0B9F\u0BCD\u0B9A\u0BBF"
    ],
    scenarioOutline: [
      "\u0B95\u0BBE\u0B9F\u0BCD\u0B9A\u0BBF \u0B9A\u0BC1\u0BB0\u0BC1\u0B95\u0BCD\u0B95\u0BAE\u0BCD",
      "\u0B95\u0BBE\u0B9F\u0BCD\u0B9A\u0BBF \u0BB5\u0BBE\u0BB0\u0BCD\u0BAA\u0BCD\u0BAA\u0BC1\u0BB0\u0BC1"
    ],
    then: [
      "* ",
      "\u0B85\u0BAA\u0BCD\u0BAA\u0BC6\u0BBE\u0BB4\u0BC1\u0BA4\u0BC1 "
    ],
    when: [
      "* ",
      "\u0B8E\u0BAA\u0BCD\u0BAA\u0BC7\u0BBE\u0BA4\u0BC1 "
    ]
  },
  th: {
    and: [
      "* ",
      "\u0E41\u0E25\u0E30 "
    ],
    background: [
      "\u0E41\u0E19\u0E27\u0E04\u0E34\u0E14"
    ],
    but: [
      "* ",
      "\u0E41\u0E15\u0E48 "
    ],
    examples: [
      "\u0E0A\u0E38\u0E14\u0E02\u0E2D\u0E07\u0E15\u0E31\u0E27\u0E2D\u0E22\u0E48\u0E32\u0E07",
      "\u0E0A\u0E38\u0E14\u0E02\u0E2D\u0E07\u0E40\u0E2B\u0E15\u0E38\u0E01\u0E32\u0E23\u0E13\u0E4C"
    ],
    feature: [
      "\u0E42\u0E04\u0E23\u0E07\u0E2B\u0E25\u0E31\u0E01",
      "\u0E04\u0E27\u0E32\u0E21\u0E15\u0E49\u0E2D\u0E07\u0E01\u0E32\u0E23\u0E17\u0E32\u0E07\u0E18\u0E38\u0E23\u0E01\u0E34\u0E08",
      "\u0E04\u0E27\u0E32\u0E21\u0E2A\u0E32\u0E21\u0E32\u0E23\u0E16"
    ],
    given: [
      "* ",
      "\u0E01\u0E33\u0E2B\u0E19\u0E14\u0E43\u0E2B\u0E49 "
    ],
    name: "Thai",
    native: "\u0E44\u0E17\u0E22",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0E40\u0E2B\u0E15\u0E38\u0E01\u0E32\u0E23\u0E13\u0E4C"
    ],
    scenarioOutline: [
      "\u0E2A\u0E23\u0E38\u0E1B\u0E40\u0E2B\u0E15\u0E38\u0E01\u0E32\u0E23\u0E13\u0E4C",
      "\u0E42\u0E04\u0E23\u0E07\u0E2A\u0E23\u0E49\u0E32\u0E07\u0E02\u0E2D\u0E07\u0E40\u0E2B\u0E15\u0E38\u0E01\u0E32\u0E23\u0E13\u0E4C"
    ],
    then: [
      "* ",
      "\u0E14\u0E31\u0E07\u0E19\u0E31\u0E49\u0E19 "
    ],
    when: [
      "* ",
      "\u0E40\u0E21\u0E37\u0E48\u0E2D "
    ]
  },
  te: {
    and: [
      "* ",
      "\u0C2E\u0C30\u0C3F\u0C2F\u0C41 "
    ],
    background: [
      "\u0C28\u0C47\u0C2A\u0C25\u0C4D\u0C2F\u0C02"
    ],
    but: [
      "* ",
      "\u0C15\u0C3E\u0C28\u0C3F "
    ],
    examples: [
      "\u0C09\u0C26\u0C3E\u0C39\u0C30\u0C23\u0C32\u0C41"
    ],
    feature: [
      "\u0C17\u0C41\u0C23\u0C2E\u0C41"
    ],
    given: [
      "* ",
      "\u0C1A\u0C46\u0C2A\u0C4D\u0C2A\u0C2C\u0C21\u0C3F\u0C28\u0C26\u0C3F "
    ],
    name: "Telugu",
    native: "\u0C24\u0C46\u0C32\u0C41\u0C17\u0C41",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0C09\u0C26\u0C3E\u0C39\u0C30\u0C23",
      "\u0C38\u0C28\u0C4D\u0C28\u0C3F\u0C35\u0C47\u0C36\u0C02"
    ],
    scenarioOutline: [
      "\u0C15\u0C25\u0C28\u0C02"
    ],
    then: [
      "* ",
      "\u0C05\u0C2A\u0C4D\u0C2A\u0C41\u0C21\u0C41 "
    ],
    when: [
      "* ",
      "\u0C08 \u0C2A\u0C30\u0C3F\u0C38\u0C4D\u0C25\u0C3F\u0C24\u0C3F\u0C32\u0C4B "
    ]
  },
  tlh: {
    and: [
      "* ",
      "'ej ",
      "latlh "
    ],
    background: [
      "mo'"
    ],
    but: [
      "* ",
      "'ach ",
      "'a "
    ],
    examples: [
      "ghantoH",
      "lutmey"
    ],
    feature: [
      "Qap",
      "Qu'meH 'ut",
      "perbogh",
      "poQbogh malja'",
      "laH"
    ],
    given: [
      "* ",
      "ghu' noblu' ",
      "DaH ghu' bejlu' "
    ],
    name: "Klingon",
    native: "tlhIngan",
    rule: [
      "Rule"
    ],
    scenario: [
      "lut"
    ],
    scenarioOutline: [
      "lut chovnatlh"
    ],
    then: [
      "* ",
      "vaj "
    ],
    when: [
      "* ",
      "qaSDI' "
    ]
  },
  tr: {
    and: [
      "* ",
      "Ve ",
      "Hem de ",
      "Bir de ",
      "Ayr\u0131ca ",
      "\u0130laveten ",
      "Buna ek olarak "
    ],
    background: [
      "Ge\xE7mi\u015F",
      "Arka Plan",
      "\xD6n Ko\u015Ful",
      "\xD6nko\u015Ful",
      "\xD6nceki Durum",
      "Giri\u015F",
      "Mukaddime",
      "Mevcut Durum"
    ],
    but: [
      "* ",
      "Fakat ",
      "Ama ",
      "Ancak ",
      "Yaln\u0131z ",
      "Lakin ",
      "Me\u011Fer ki ",
      "Buna mukabil ",
      "Aksi halde "
    ],
    examples: [
      "\xD6rnekler",
      "De\u011Ferler"
    ],
    feature: [
      "\xD6zellik",
      "\u0130\u015F Gereksinimi",
      "Gereksinim",
      "\u0130\u015Flev",
      "Kullan\u0131c\u0131 Hikayesi",
      "Yetenek",
      "Teknik Gereksinim"
    ],
    given: [
      "* ",
      "Mevcut ",
      "\xD6nceden ",
      "Ge\xE7mi\u015Fte ",
      "Daha \xF6nce ",
      "Halihaz\u0131rda ",
      "Zaten ",
      "Sistemde ",
      "Diyelim ki ",
      "Varsayal\u0131m ki ",
      "Farz edelim ki ",
      "Kabul edelim ki ",
      "Ba\u015Flang\u0131\xE7ta ",
      "Varsay\u0131lan olarak ",
      "Biliniyor ki "
    ],
    name: "Turkish",
    native: "T\xFCrk\xE7e",
    rule: [
      "Kural",
      "\u0130\u015F Kural\u0131",
      "Kaide",
      "H\xFCk\xFCm",
      "Madde"
    ],
    scenario: [
      "\xD6rnek",
      "Senaryo",
      "Durum",
      "Vaka"
    ],
    scenarioOutline: [
      "Senaryo tasla\u011F\u0131",
      "Senaryo \u015Fablonu"
    ],
    then: [
      "* ",
      "Beklenen ",
      "O zaman ",
      "Sonu\xE7 olarak ",
      "B\xF6ylece ",
      "Bunun \xFCzerine ",
      "Bu durumda ",
      "O takdirde ",
      "\u015Eu halde ",
      "Netice itibariyle ",
      "Buna binaen "
    ],
    when: [
      "* ",
      "E\u011Fer ",
      "E\u011Fer ki ",
      "Ne zaman ",
      "Ne zaman ki ",
      "\u015Eayet "
    ]
  },
  tt: {
    and: [
      "* ",
      "\u04BA\u04D9\u043C ",
      "\u0412\u04D9 "
    ],
    background: [
      "\u041A\u0435\u0440\u0435\u0448"
    ],
    but: [
      "* ",
      "\u041B\u04D9\u043A\u0438\u043D ",
      "\u04D8\u043C\u043C\u0430 "
    ],
    examples: [
      "\u04AE\u0440\u043D\u04D9\u043A\u043B\u04D9\u0440",
      "\u041C\u0438\u0441\u0430\u043B\u043B\u0430\u0440"
    ],
    feature: [
      "\u041C\u04E9\u043C\u043A\u0438\u043D\u043B\u0435\u043A",
      "\u04AE\u0437\u0435\u043D\u0447\u04D9\u043B\u0435\u043A\u043B\u0435\u043B\u0435\u043A"
    ],
    given: [
      "* ",
      "\u04D8\u0439\u0442\u0438\u043A "
    ],
    name: "Tatar",
    native: "\u0422\u0430\u0442\u0430\u0440\u0447\u0430",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439"
    ],
    scenarioOutline: [
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439\u043D\u044B\u04A3 \u0442\u04E9\u0437\u0435\u043B\u0435\u0448\u0435"
    ],
    then: [
      "* ",
      "\u041D\u04D9\u0442\u0438\u0497\u04D9\u0434\u04D9 "
    ],
    when: [
      "* ",
      "\u04D8\u0433\u04D9\u0440 "
    ]
  },
  uk: {
    and: [
      "* ",
      "\u0406 ",
      "\u0410 \u0442\u0430\u043A\u043E\u0436 ",
      "\u0422\u0430 "
    ],
    background: [
      "\u041F\u0435\u0440\u0435\u0434\u0443\u043C\u043E\u0432\u0430"
    ],
    but: [
      "* ",
      "\u0410\u043B\u0435 "
    ],
    examples: [
      "\u041F\u0440\u0438\u043A\u043B\u0430\u0434\u0438"
    ],
    feature: [
      "\u0424\u0443\u043D\u043A\u0446\u0456\u043E\u043D\u0430\u043B"
    ],
    given: [
      "* ",
      "\u041F\u0440\u0438\u043F\u0443\u0441\u0442\u0438\u043C\u043E ",
      "\u041F\u0440\u0438\u043F\u0443\u0441\u0442\u0438\u043C\u043E, \u0449\u043E ",
      "\u041D\u0435\u0445\u0430\u0439 ",
      "\u0414\u0430\u043D\u043E "
    ],
    name: "Ukrainian",
    native: "\u0423\u043A\u0440\u0430\u0457\u043D\u0441\u044C\u043A\u0430",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u041F\u0440\u0438\u043A\u043B\u0430\u0434",
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0456\u0439"
    ],
    scenarioOutline: [
      "\u0421\u0442\u0440\u0443\u043A\u0442\u0443\u0440\u0430 \u0441\u0446\u0435\u043D\u0430\u0440\u0456\u044E"
    ],
    then: [
      "* ",
      "\u0422\u043E ",
      "\u0422\u043E\u0434\u0456 "
    ],
    when: [
      "* ",
      "\u042F\u043A\u0449\u043E ",
      "\u041A\u043E\u043B\u0438 "
    ]
  },
  ur: {
    and: [
      "* ",
      "\u0627\u0648\u0631 "
    ],
    background: [
      "\u067E\u0633 \u0645\u0646\u0638\u0631"
    ],
    but: [
      "* ",
      "\u0644\u06CC\u06A9\u0646 "
    ],
    examples: [
      "\u0645\u062B\u0627\u0644\u06CC\u06BA"
    ],
    feature: [
      "\u0635\u0644\u0627\u062D\u06CC\u062A",
      "\u06A9\u0627\u0631\u0648\u0628\u0627\u0631 \u06A9\u06CC \u0636\u0631\u0648\u0631\u062A",
      "\u062E\u0635\u0648\u0635\u06CC\u062A"
    ],
    given: [
      "* ",
      "\u0627\u06AF\u0631 ",
      "\u0628\u0627\u0644\u0641\u0631\u0636 ",
      "\u0641\u0631\u0636 \u06A9\u06CC\u0627 "
    ],
    name: "Urdu",
    native: "\u0627\u0631\u062F\u0648",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0645\u0646\u0638\u0631\u0646\u0627\u0645\u06C1"
    ],
    scenarioOutline: [
      "\u0645\u0646\u0638\u0631 \u0646\u0627\u0645\u06D2 \u06A9\u0627 \u062E\u0627\u06A9\u06C1"
    ],
    then: [
      "* ",
      "\u067E\u06BE\u0631 ",
      "\u062A\u0628 "
    ],
    when: [
      "* ",
      "\u062C\u0628 "
    ]
  },
  uz: {
    and: [
      "* ",
      "\u0412\u0430 "
    ],
    background: [
      "\u0422\u0430\u0440\u0438\u0445"
    ],
    but: [
      "* ",
      "\u041B\u0435\u043A\u0438\u043D ",
      "\u0411\u0438\u0440\u043E\u043A ",
      "\u0410\u043C\u043C\u043E "
    ],
    examples: [
      "\u041C\u0438\u0441\u043E\u043B\u043B\u0430\u0440"
    ],
    feature: [
      "\u0424\u0443\u043D\u043A\u0446\u0438\u043E\u043D\u0430\u043B"
    ],
    given: [
      "* ",
      "Belgilangan "
    ],
    name: "Uzbek",
    native: "\u0423\u0437\u0431\u0435\u043A\u0447\u0430",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439"
    ],
    scenarioOutline: [
      "\u0421\u0446\u0435\u043D\u0430\u0440\u0438\u0439 \u0441\u0442\u0440\u0443\u043A\u0442\u0443\u0440\u0430\u0441\u0438"
    ],
    then: [
      "* ",
      "\u0423\u043D\u0434\u0430 "
    ],
    when: [
      "* ",
      "\u0410\u0433\u0430\u0440 "
    ]
  },
  vi: {
    and: [
      "* ",
      "V\xE0 "
    ],
    background: [
      "B\u1ED1i c\u1EA3nh"
    ],
    but: [
      "* ",
      "Nh\u01B0ng "
    ],
    examples: [
      "D\u1EEF li\u1EC7u"
    ],
    feature: [
      "T\xEDnh n\u0103ng"
    ],
    given: [
      "* ",
      "Bi\u1EBFt ",
      "Cho "
    ],
    name: "Vietnamese",
    native: "Ti\u1EBFng Vi\u1EC7t",
    rule: [
      "Quy t\u1EAFc"
    ],
    scenario: [
      "T\xECnh hu\u1ED1ng",
      "K\u1ECBch b\u1EA3n"
    ],
    scenarioOutline: [
      "Khung t\xECnh hu\u1ED1ng",
      "Khung k\u1ECBch b\u1EA3n"
    ],
    then: [
      "* ",
      "Th\xEC "
    ],
    when: [
      "* ",
      "Khi "
    ]
  },
  "zh-CN": {
    and: [
      "* ",
      "\u800C\u4E14",
      "\u5E76\u4E14",
      "\u540C\u65F6"
    ],
    background: [
      "\u80CC\u666F"
    ],
    but: [
      "* ",
      "\u4F46\u662F"
    ],
    examples: [
      "\u4F8B\u5B50"
    ],
    feature: [
      "\u529F\u80FD"
    ],
    given: [
      "* ",
      "\u5047\u5982",
      "\u5047\u8BBE",
      "\u5047\u5B9A"
    ],
    name: "Chinese simplified",
    native: "\u7B80\u4F53\u4E2D\u6587",
    rule: [
      "Rule",
      "\u89C4\u5219"
    ],
    scenario: [
      "\u573A\u666F",
      "\u5267\u672C"
    ],
    scenarioOutline: [
      "\u573A\u666F\u5927\u7EB2",
      "\u5267\u672C\u5927\u7EB2"
    ],
    then: [
      "* ",
      "\u90A3\u4E48"
    ],
    when: [
      "* ",
      "\u5F53"
    ]
  },
  ml: {
    and: [
      "* ",
      "\u0D12\u0D2A\u0D4D\u0D2A\u0D02"
    ],
    background: [
      "\u0D2A\u0D36\u0D4D\u0D1A\u0D3E\u0D24\u0D4D\u0D24\u0D32\u0D02"
    ],
    but: [
      "* ",
      "\u0D2A\u0D15\u0D4D\u0D37\u0D47"
    ],
    examples: [
      "\u0D09\u0D26\u0D3E\u0D39\u0D30\u0D23\u0D19\u0D4D\u0D19\u0D7E"
    ],
    feature: [
      "\u0D38\u0D35\u0D3F\u0D36\u0D47\u0D37\u0D24"
    ],
    given: [
      "* ",
      "\u0D28\u0D7D\u0D15\u0D3F\u0D2F\u0D24\u0D4D"
    ],
    name: "Malayalam",
    native: "\u0D2E\u0D32\u0D2F\u0D3E\u0D33\u0D02",
    rule: [
      "\u0D28\u0D3F\u0D2F\u0D2E\u0D02"
    ],
    scenario: [
      "\u0D30\u0D02\u0D17\u0D02"
    ],
    scenarioOutline: [
      "\u0D38\u0D3E\u0D39\u0D1A\u0D30\u0D4D\u0D2F\u0D24\u0D4D\u0D24\u0D3F\u0D28\u0D4D\u0D31\u0D46 \u0D30\u0D42\u0D2A\u0D30\u0D47\u0D16"
    ],
    then: [
      "* ",
      "\u0D2A\u0D3F\u0D28\u0D4D\u0D28\u0D46"
    ],
    when: [
      "\u0D0E\u0D2A\u0D4D\u0D2A\u0D47\u0D3E\u0D7E"
    ]
  },
  "zh-TW": {
    and: [
      "* ",
      "\u800C\u4E14",
      "\u4E26\u4E14",
      "\u540C\u6642"
    ],
    background: [
      "\u80CC\u666F"
    ],
    but: [
      "* ",
      "\u4F46\u662F"
    ],
    examples: [
      "\u4F8B\u5B50"
    ],
    feature: [
      "\u529F\u80FD"
    ],
    given: [
      "* ",
      "\u5047\u5982",
      "\u5047\u8A2D",
      "\u5047\u5B9A"
    ],
    name: "Chinese traditional",
    native: "\u7E41\u9AD4\u4E2D\u6587",
    rule: [
      "Rule"
    ],
    scenario: [
      "\u5834\u666F",
      "\u5287\u672C"
    ],
    scenarioOutline: [
      "\u5834\u666F\u5927\u7DB1",
      "\u5287\u672C\u5927\u7DB1"
    ],
    then: [
      "* ",
      "\u90A3\u9EBC"
    ],
    when: [
      "* ",
      "\u7576"
    ]
  },
  mr: {
    and: [
      "* ",
      "\u0906\u0923\u093F ",
      "\u0924\u0938\u0947\u091A "
    ],
    background: [
      "\u092A\u093E\u0930\u094D\u0936\u094D\u0935\u092D\u0942\u092E\u0940"
    ],
    but: [
      "* ",
      "\u092A\u0923 ",
      "\u092A\u0930\u0902\u0924\u0941 "
    ],
    examples: [
      "\u0909\u0926\u093E\u0939\u0930\u0923"
    ],
    feature: [
      "\u0935\u0948\u0936\u093F\u0937\u094D\u091F\u094D\u092F",
      "\u0938\u0941\u0935\u093F\u0927\u093E"
    ],
    given: [
      "* ",
      "\u091C\u0930",
      "\u0926\u093F\u0932\u0947\u0932\u094D\u092F\u093E \u092A\u094D\u0930\u092E\u093E\u0923\u0947 "
    ],
    name: "Marathi",
    native: "\u092E\u0930\u093E\u0920\u0940",
    rule: [
      "\u0928\u093F\u092F\u092E"
    ],
    scenario: [
      "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F"
    ],
    scenarioOutline: [
      "\u092A\u0930\u093F\u0926\u0943\u0936\u094D\u092F \u0930\u0942\u092A\u0930\u0947\u0916\u093E"
    ],
    then: [
      "* ",
      "\u092E\u0917 ",
      "\u0924\u0947\u0935\u094D\u0939\u093E "
    ],
    when: [
      "* ",
      "\u091C\u0947\u0935\u094D\u0939\u093E "
    ]
  },
  amh: {
    and: [
      "* ",
      "\u12A5\u1293 "
    ],
    background: [
      "\u1245\u12F5\u1218 \u1201\u1294\u1273",
      "\u1218\u1290\u123B",
      "\u1218\u1290\u123B \u1200\u1233\u1265"
    ],
    but: [
      "* ",
      "\u130D\u1295 "
    ],
    examples: [
      "\u121D\u1233\u120C\u12CE\u127D",
      "\u1201\u1293\u1274\u12CE\u127D"
    ],
    feature: [
      "\u1235\u122B",
      "\u12E8\u1270\u1348\u1208\u1308\u12CD \u1235\u122B",
      "\u12E8\u121A\u1348\u1208\u1308\u12CD \u12F5\u122D\u130A\u1275"
    ],
    given: [
      "* ",
      "\u12E8\u1270\u1230\u1320 "
    ],
    name: "Amharic",
    native: "\u12A0\u121B\u122D\u129B",
    rule: [
      "\u1205\u130D"
    ],
    scenario: [
      "\u121D\u1233\u120C",
      "\u1201\u1293\u1274"
    ],
    scenarioOutline: [
      "\u1201\u1293\u1274 \u12DD\u122D\u12DD\u122D",
      "\u1201\u1293\u1274 \u12A0\u1265\u1290\u1275"
    ],
    then: [
      "* ",
      "\u12A8\u12DA\u12EB "
    ],
    when: [
      "* ",
      "\u1218\u127C "
    ]
  }
};

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/GherkinClassicTokenMatcher.js
var DIALECT_DICT = gherkin_languages_default;
var LANGUAGE_PATTERN = /^\s*#\s*language\s*:\s*([a-zA-Z\-_]+)\s*$/;
function addKeywordTypeMappings(h, keywords, keywordType) {
  for (const k of keywords) {
    if (!(k in h)) {
      h[k] = [];
    }
    h[k].push(keywordType);
  }
}
var GherkinClassicTokenMatcher = class {
  defaultDialectName;
  dialect;
  dialectName;
  activeDocStringSeparator;
  indentToRemove;
  keywordTypesMap;
  sortedStepKeywords;
  constructor(defaultDialectName = "en") {
    this.defaultDialectName = defaultDialectName;
    this.reset();
  }
  changeDialect(newDialectName, location) {
    const newDialect = DIALECT_DICT[newDialectName];
    if (!newDialect) {
      throw NoSuchLanguageException.create(newDialectName, location);
    }
    this.dialectName = newDialectName;
    this.dialect = newDialect;
    this.initializeKeywordTypes();
    this.initializeSortedStepKeywords();
  }
  reset() {
    if (this.dialectName !== this.defaultDialectName) {
      this.changeDialect(this.defaultDialectName);
    }
    this.activeDocStringSeparator = null;
    this.indentToRemove = 0;
  }
  initializeKeywordTypes() {
    this.keywordTypesMap = {};
    addKeywordTypeMappings(this.keywordTypesMap, this.dialect.given, StepKeywordType.CONTEXT);
    addKeywordTypeMappings(this.keywordTypesMap, this.dialect.when, StepKeywordType.ACTION);
    addKeywordTypeMappings(this.keywordTypesMap, this.dialect.then, StepKeywordType.OUTCOME);
    addKeywordTypeMappings(this.keywordTypesMap, [].concat(this.dialect.and).concat(this.dialect.but), StepKeywordType.CONJUNCTION);
  }
  initializeSortedStepKeywords() {
    this.sortedStepKeywords = [].concat(this.dialect.given).concat(this.dialect.when).concat(this.dialect.then).concat(this.dialect.and).concat(this.dialect.but).sort(compareStepKeywords);
  }
  match_TagLine(token) {
    if (token.line.startsWith("@")) {
      this.setTokenMatched(token, TokenType.TagLine, null, null, null, null, this.getTags(token.line));
      return true;
    }
    return false;
  }
  match_FeatureLine(token) {
    return this.matchTitleLine(token, TokenType.FeatureLine, this.dialect.feature);
  }
  match_ScenarioLine(token) {
    return this.matchTitleLine(token, TokenType.ScenarioLine, this.dialect.scenario) || this.matchTitleLine(token, TokenType.ScenarioLine, this.dialect.scenarioOutline);
  }
  match_BackgroundLine(token) {
    return this.matchTitleLine(token, TokenType.BackgroundLine, this.dialect.background);
  }
  match_ExamplesLine(token) {
    return this.matchTitleLine(token, TokenType.ExamplesLine, this.dialect.examples);
  }
  match_RuleLine(token) {
    return this.matchTitleLine(token, TokenType.RuleLine, this.dialect.rule);
  }
  match_TableRow(token) {
    if (token.line.startsWith("|")) {
      this.setTokenMatched(token, TokenType.TableRow, null, null, null, null, token.line.getTableCells());
      return true;
    }
    return false;
  }
  match_Empty(token) {
    if (token.line.isEmpty) {
      this.setTokenMatched(token, TokenType.Empty, null, null, 0);
      return true;
    }
    return false;
  }
  match_Comment(token) {
    if (token.line.startsWith("#")) {
      const text = token.line.getLineText(0);
      this.setTokenMatched(token, TokenType.Comment, text, null, 0);
      return true;
    }
    return false;
  }
  match_Language(token) {
    const match = token.line.trimmedLineText.match(LANGUAGE_PATTERN);
    if (match) {
      const newDialectName = match[1];
      this.setTokenMatched(token, TokenType.Language, newDialectName);
      this.changeDialect(newDialectName, token.location);
      return true;
    }
    return false;
  }
  match_DocStringSeparator(token) {
    return this.activeDocStringSeparator == null ? (
      // open
      this._match_DocStringSeparator(token, '"""', true) || this._match_DocStringSeparator(token, "```", true)
    ) : (
      // close
      this._match_DocStringSeparator(token, this.activeDocStringSeparator, false)
    );
  }
  _match_DocStringSeparator(token, separator, isOpen) {
    if (token.line.startsWith(separator)) {
      let mediaType = null;
      if (isOpen) {
        mediaType = token.line.getRestTrimmed(separator.length);
        this.activeDocStringSeparator = separator;
        this.indentToRemove = token.line.indent;
      } else {
        this.activeDocStringSeparator = null;
        this.indentToRemove = 0;
      }
      this.setTokenMatched(token, TokenType.DocStringSeparator, mediaType, separator);
      return true;
    }
    return false;
  }
  match_EOF(token) {
    if (token.isEof) {
      this.setTokenMatched(token, TokenType.EOF);
      return true;
    }
    return false;
  }
  match_StepLine(token) {
    for (const keyword of this.sortedStepKeywords) {
      if (token.line.startsWith(keyword)) {
        const title = token.line.getRestTrimmed(keyword.length);
        const keywordTypes = this.keywordTypesMap[keyword];
        let keywordType = keywordTypes[0];
        if (keywordTypes.length > 1) {
          keywordType = StepKeywordType.UNKNOWN;
        }
        this.setTokenMatched(token, TokenType.StepLine, title, keyword, null, keywordType);
        return true;
      }
    }
    return false;
  }
  match_Other(token) {
    const text = token.line.getLineText(this.indentToRemove);
    this.setTokenMatched(token, TokenType.Other, this.unescapeDocString(text), null, 0);
    return true;
  }
  getTags(line) {
    const uncommentedLine = line.trimmedLineText.split(/\s#/g, 2)[0];
    let column = line.indent + 1;
    const items = uncommentedLine.split("@");
    const tags = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i].trimRight();
      if (item.length === 0) {
        continue;
      }
      if (!item.match(/^\S+$/)) {
        throw ParserException.create("A tag may not contain whitespace", line.lineNumber, column);
      }
      const span = { column, text: `@${item}` };
      tags.push(span);
      column += countSymbols(items[i]) + 1;
    }
    return tags;
  }
  matchTitleLine(token, tokenType, keywords) {
    for (const keyword of keywords) {
      if (token.line.startsWithTitleKeyword(keyword)) {
        const title = token.line.getRestTrimmed(keyword.length + ":".length);
        this.setTokenMatched(token, tokenType, title, keyword);
        return true;
      }
    }
    return false;
  }
  setTokenMatched(token, matchedType, text, keyword, indent, keywordType, items) {
    token.matchedType = matchedType;
    token.matchedText = text;
    token.matchedKeyword = keyword;
    token.matchedKeywordType = keywordType;
    token.matchedIndent = typeof indent === "number" ? indent : token.line == null ? 0 : token.line.indent;
    token.matchedItems = items || [];
    token.location.column = token.matchedIndent + 1;
    token.matchedGherkinDialect = this.dialectName;
  }
  unescapeDocString(text) {
    if (this.activeDocStringSeparator === '"""') {
      return text.replace('\\"\\"\\"', '"""');
    }
    if (this.activeDocStringSeparator === "```") {
      return text.replace("\\`\\`\\`", "```");
    }
    return text;
  }
};

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/GherkinInMarkdownTokenMatcher.js
var KeywordPrefix;
(function(KeywordPrefix2) {
  KeywordPrefix2["BULLET"] = "^(\\s*[*+-]\\s*)";
  KeywordPrefix2["HEADER"] = "^(#{1,6}\\s)";
})(KeywordPrefix || (KeywordPrefix = {}));

// node_modules/.pnpm/@cucumber+gherkin@42.0.1/node_modules/@cucumber/gherkin/dist/pickles/compile.js
var pickleStepTypeFromKeyword = {
  [StepKeywordType.UNKNOWN]: PickleStepType.UNKNOWN,
  [StepKeywordType.CONTEXT]: PickleStepType.CONTEXT,
  [StepKeywordType.ACTION]: PickleStepType.ACTION,
  [StepKeywordType.OUTCOME]: PickleStepType.OUTCOME,
  [StepKeywordType.CONJUNCTION]: null
};
function compile(gherkinDocument, uri, newId) {
  const pickles = [];
  if (gherkinDocument.feature == null) {
    return pickles;
  }
  const feature = gherkinDocument.feature;
  const language = feature.language;
  const featureTags = feature.tags;
  let featureBackgroundSteps = [];
  feature.children.forEach((stepsContainer) => {
    if (stepsContainer.background) {
      featureBackgroundSteps = [].concat(stepsContainer.background.steps);
    } else if (stepsContainer.rule) {
      compileRule(featureTags, featureBackgroundSteps, stepsContainer.rule, language, pickles, uri, newId);
    } else if (stepsContainer.scenario.examples.length === 0) {
      compileScenario(featureTags, featureBackgroundSteps, stepsContainer.scenario, language, pickles, uri, newId);
    } else {
      compileScenarioOutline(featureTags, featureBackgroundSteps, stepsContainer.scenario, language, pickles, uri, newId);
    }
  });
  return pickles;
}
function compileRule(featureTags, featureBackgroundSteps, rule, language, pickles, uri, newId) {
  let ruleBackgroundSteps = [].concat(featureBackgroundSteps);
  const tags = [].concat(featureTags).concat(rule.tags);
  rule.children.forEach((stepsContainer) => {
    if (stepsContainer.background) {
      ruleBackgroundSteps = ruleBackgroundSteps.concat(stepsContainer.background.steps);
    } else if (stepsContainer.scenario.examples.length === 0) {
      compileScenario(tags, ruleBackgroundSteps, stepsContainer.scenario, language, pickles, uri, newId);
    } else {
      compileScenarioOutline(tags, ruleBackgroundSteps, stepsContainer.scenario, language, pickles, uri, newId);
    }
  });
}
function compileScenario(inheritedTags, backgroundSteps, scenario, language, pickles, uri, newId) {
  let lastKeywordType = StepKeywordType.UNKNOWN;
  const steps = [];
  if (scenario.steps.length !== 0) {
    backgroundSteps.forEach((step) => {
      lastKeywordType = step.keywordType === StepKeywordType.CONJUNCTION ? lastKeywordType : step.keywordType;
      steps.push(pickleStep(step, [], null, newId, lastKeywordType));
    });
  }
  const tags = [].concat(inheritedTags).concat(scenario.tags);
  scenario.steps.forEach((step) => {
    lastKeywordType = step.keywordType === StepKeywordType.CONJUNCTION ? lastKeywordType : step.keywordType;
    steps.push(pickleStep(step, [], null, newId, lastKeywordType));
  });
  const pickle = {
    id: newId(),
    uri,
    location: scenario.location,
    astNodeIds: [scenario.id],
    tags: pickleTags(tags),
    name: scenario.name,
    language,
    steps
  };
  pickles.push(pickle);
}
function compileScenarioOutline(inheritedTags, backgroundSteps, scenario, language, pickles, uri, newId) {
  scenario.examples.filter((e) => e.tableHeader).forEach((examples) => {
    const variableCells = examples.tableHeader.cells;
    examples.tableBody.forEach((valuesRow) => {
      let lastKeywordType = StepKeywordType.UNKNOWN;
      const steps = [];
      if (scenario.steps.length !== 0) {
        backgroundSteps.forEach((step) => {
          lastKeywordType = step.keywordType === StepKeywordType.CONJUNCTION ? lastKeywordType : step.keywordType;
          steps.push(pickleStep(step, [], null, newId, lastKeywordType));
        });
      }
      scenario.steps.forEach((scenarioOutlineStep) => {
        lastKeywordType = scenarioOutlineStep.keywordType === StepKeywordType.CONJUNCTION ? lastKeywordType : scenarioOutlineStep.keywordType;
        const step = pickleStep(scenarioOutlineStep, variableCells, valuesRow, newId, lastKeywordType);
        steps.push(step);
      });
      const id = newId();
      const tags = pickleTags([].concat(inheritedTags).concat(scenario.tags).concat(examples.tags));
      pickles.push({
        id,
        uri,
        location: valuesRow.location,
        astNodeIds: [scenario.id, valuesRow.id],
        name: interpolate(scenario.name, variableCells, valuesRow.cells),
        language,
        steps,
        tags
      });
    });
  });
}
function pickleDocString(argumentIndex, argument, variableCells, valueCells) {
  return {
    argumentIndex,
    content: interpolate(argument.content, variableCells, valueCells),
    mediaType: argument.mediaType ? interpolate(argument.mediaType, variableCells, valueCells) : void 0
  };
}
function pickleTable(argumentIndex, argument, variableCells, valueCells) {
  return {
    argumentIndex,
    rows: argument.rows.map((row) => {
      return {
        cells: row.cells.map((cell) => {
          return {
            value: interpolate(cell.value, variableCells, valueCells)
          };
        })
      };
    })
  };
}
function createPickleArguments(step, variableCells, valueCells) {
  if (step.dataTable && step.docString) {
    const tableFirst = step.docString.location.line > step.dataTable.location.line;
    return {
      docString: pickleDocString(tableFirst ? 2 : 1, step.docString, variableCells, valueCells),
      dataTable: pickleTable(tableFirst ? 1 : 2, step.dataTable, variableCells, valueCells)
    };
  } else if (step.dataTable) {
    return {
      dataTable: pickleTable(void 0, step.dataTable, variableCells, valueCells)
    };
  } else if (step.docString) {
    return {
      docString: pickleDocString(void 0, step.docString, variableCells, valueCells)
    };
  }
  return void 0;
}
function interpolate(name, variableCells, valueCells) {
  variableCells.forEach((variableCell, n) => {
    const valueCell = valueCells[n];
    const valuePattern = `<${variableCell.value}>`;
    const escapedPattern = valuePattern.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
    const regexp = new RegExp(escapedPattern, "g");
    const replacement = valueCell.value.replace(/\$/g, "$$$$");
    name = name.replace(regexp, replacement);
  });
  return name;
}
function pickleStep(step, variableCells, valuesRow, newId, keywordType) {
  const astNodeIds = [step.id];
  if (valuesRow) {
    astNodeIds.push(valuesRow.id);
  }
  const valueCells = valuesRow ? valuesRow.cells : [];
  return {
    id: newId(),
    text: interpolate(step.text, variableCells, valueCells),
    type: pickleStepTypeFromKeyword[keywordType],
    argument: createPickleArguments(step, variableCells, valueCells),
    astNodeIds
  };
}
function pickleTags(tags) {
  return tags.map(pickleTag);
}
function pickleTag(tag) {
  return {
    name: tag.name,
    astNodeId: tag.id
  };
}

// src/example.ts
function toScenario(s, pickles) {
  const stepsOf = (key) => (pickles.get(key)?.steps ?? []).map((st) => st.text.trim());
  const expansions = [];
  if (s.examples.length === 0) {
    expansions.push({ label: "", steps: stepsOf(s.id) });
  } else {
    let n = 0;
    for (const ex of s.examples) {
      if (ex.tableHeader === void 0) continue;
      for (const row of ex.tableBody) {
        n++;
        expansions.push({ label: `#${n}`, steps: stepsOf(`${s.id}|${row.id}`) });
      }
    }
  }
  return { name: s.name, line: s.location.line, expansions };
}
function parseExample(source) {
  const newId = IdGenerator_exports.incrementing();
  let doc;
  try {
    doc = new Parser(new AstBuilder(newId), new GherkinClassicTokenMatcher()).parse(source);
  } catch (e) {
    const errors = e.message.split("\n").map((l) => l.trim()).filter((l) => l !== "" && l !== "Parser errors:");
    const message = errors.length > 1 ? `${errors[0]}\uFF08\u307B\u304B ${errors.length - 1} \u4EF6\uFF09` : errors[0] ?? e.message;
    return { ok: false, message };
  }
  if (doc.feature === void 0) return { ok: true, feature: null };
  const pickles = /* @__PURE__ */ new Map();
  for (const p of compile(doc, "", newId)) pickles.set(p.astNodeIds.join("|"), p);
  const feature = { name: doc.feature.name.trim(), rules: [], looseScenarios: [] };
  for (const child of doc.feature.children) {
    if (child.rule !== void 0) {
      feature.rules.push({
        name: child.rule.name.trim(),
        line: child.rule.location.line,
        scenarios: child.rule.children.filter((c) => c.scenario !== void 0).map((c) => toScenario(c.scenario, pickles))
      });
    } else if (child.scenario !== void 0) {
      feature.looseScenarios.push(toScenario(child.scenario, pickles));
    }
  }
  return { ok: true, feature };
}

// src/requirement.ts
function parseRequirement(source) {
  const text = source.replace(/^﻿/, "").replace(/<!--[\s\S]*?(?:-->|$)/g, "");
  const lines = text.split(/\r?\n/);
  let ucName = null;
  let titleSeen = false;
  let inSpec = false;
  let inReason = false;
  let reason = null;
  const out = [];
  for (const line of lines) {
    if (/^#\s/.test(line)) {
      if (!titleSeen) {
        titleSeen = true;
        const m = line.match(new RegExp(`^#\\s+${REQUIREMENT_TITLE_LABEL}[:\uFF1A]\\s*(.*?)\\s*$`));
        ucName = m !== null && m[1] !== "" ? m[1] : null;
      }
      continue;
    }
    if (/^##\s/.test(line)) {
      const heading = line.replace(/^##\s+/, "").trim();
      inSpec = heading === REQUIREMENT_SPEC_HEADING;
      inReason = heading === REQUIREMENT_REASON_HEADING;
      if (inReason && reason === null) reason = [];
      continue;
    }
    if (inReason) {
      if (line.trim() !== "") reason.push(line.trim());
      continue;
    }
    if (!inSpec) continue;
    const spec = line.match(/^\d+\.(?:\s+(.*?))?\s*$/);
    if (spec !== null) {
      out.push({ ordinal: out.length + 1, text: spec[1] ?? "", rdra: null, reason: null });
      continue;
    }
    const field = line.match(new RegExp(`^\\s+[-*]\\s+${REQUIREMENT_RDRA_FIELD}[:\uFF1A]\\s*(.*?)\\s*$`));
    const current = out[out.length - 1];
    if (field !== null && current !== void 0 && current.rdra === null) current.rdra = field[1];
    const reasonField = line.match(new RegExp(`^\\s+[-*]\\s+${REQUIREMENT_REASON_FIELD}[:\uFF1A]\\s*(.*?)\\s*$`));
    if (reasonField !== null && current !== void 0 && current.reason === null) current.reason = reasonField[1];
  }
  return { ucName, reason: reason === null ? null : reason.join("\n"), lines: out };
}
function parseReferences(rdra) {
  if (rdra === null) return [];
  const value = rdra.trim();
  if (value === "" || value === REQUIREMENT_NO_REFERENCE) return [];
  const parts = [];
  let depth = 0;
  let current = "";
  for (const ch of value) {
    if (ch === "\u300C") depth++;
    if (ch === "\u300D" && depth > 0) depth--;
    if (ch === "\u3001" && depth === 0) {
      parts.push(current);
      current = "";
      continue;
    }
    current += ch;
  }
  parts.push(current);
  return parts.map((p) => {
    const raw = p.trim();
    const m = raw.match(/^([^「」]+)「(.+)」$/);
    if (m === null || m[2].trim() === "") return { raw, kind: null, name: null };
    return { raw, kind: m[1].trim(), name: m[2].trim() };
  });
}

// src/trace.ts
function listFiles(root, dir, ext) {
  const path = join2(root, dir);
  if (!existsSync2(path)) return [];
  return readdirSync(path).filter((f) => f.endsWith(ext)).sort().map((f) => `${dir}/${f}`);
}
function splitState(name) {
  const i = name.indexOf(REQUIREMENT_STATE_SEP);
  if (i < 0) return null;
  return { model: name.slice(0, i).trim(), state: name.slice(i + REQUIREMENT_STATE_SEP.length).trim() };
}
function referenceProblem(ref, ctx) {
  if (ref.kind === null || ref.name === null) {
    return ref.raw === "" ? "\u7A7A\u306E\u8981\u7D20\u304C\u3042\u308B\uFF08\u300C\u3001\u300D\u306E\u91CD\u8907\u30FB\u672B\u5C3E\uFF09" : `\u300E${ref.raw}\u300F\u304C <\u7A2E\u985E>\u300C<\u540D\u524D>\u300D\u306E\u5F62\u3067\u8AAD\u3081\u306A\u3044`;
  }
  if (!REQUIREMENT_KINDS.includes(ref.kind)) {
    return `\u7A2E\u985E\u300E${ref.kind}\u300F\u304C\u8A9E\u5F59\uFF08${REQUIREMENT_KINDS.join("\uFF0F")}\uFF09\u306B\u7121\u3044`;
  }
  if (ref.kind === "\u72B6\u614B") {
    const s = splitState(ref.name);
    if (s === null) return `\u72B6\u614B\u306E\u540D\u524D\u306F\u300E\u72B6\u614B\u300C<\u72B6\u614B\u30E2\u30C7\u30EB>${REQUIREMENT_STATE_SEP}<\u72B6\u614B>\u300D\u300F\u306E\u5F62\u3067\u66F8\u304F`;
    const states = ctx.statesOf.get(s.model);
    if (states === void 0) return `\u72B6\u614B\u30E2\u30C7\u30EB\u300E${s.model}\u300F\u304C\u72B6\u614B\u306E\u8868\u306B\u7121\u3044\uFF08\u72B6\u614B\u300E${ref.name}\u300F\uFF09`;
    if (!states.has(s.state)) {
      return `\u72B6\u614B\u300E${s.state}\u300F\u304C\u72B6\u614B\u30E2\u30C7\u30EB\u300E${s.model}\u300F\u306E\u300C\u72B6\u614B\u300D\u300C\u9077\u79FB\u5148\u72B6\u614B\u300D\u306E\u3069\u3061\u3089\u306B\u3082\u7121\u3044`;
    }
    return null;
  }
  if (ctx.names.get(ref.kind)?.has(ref.name)) return null;
  return `${ref.kind}\u300E${ref.name}\u300F\u304C\u8868\u306B\u7121\u3044`;
}
function nameInText(ref) {
  if (ref.kind === null || ref.name === null) return null;
  if (ref.kind === "\u72B6\u614B") return splitState(ref.name)?.state ?? null;
  return ref.name;
}
function refKey(kind, name) {
  if (kind === "\u72B6\u614B") {
    const s = splitState(name);
    if (s !== null) return `${kind}\0${s.model}${REQUIREMENT_STATE_SEP}${s.state}`;
  }
  return `${kind}\0${name}`;
}
function addTo(map, key, value) {
  const list2 = map.get(key);
  if (list2 === void 0) map.set(key, [value]);
  else list2.push(value);
}
function checkTrace(root, ctx) {
  const out = [];
  const missing = [];
  const ucNames = ctx.names.get("UC") ?? /* @__PURE__ */ new Set();
  const reqFiles = listFiles(root, LAYOUT.requirements, ".md").map((file) => {
    const req = parseRequirement(readFileSync2(join2(root, file), "utf8"));
    return { file, req, refs: req.lines.map((l) => ({ refs: parseReferences(l.rdra) })) };
  });
  const filesOfUc = /* @__PURE__ */ new Map();
  for (const { file, req } of reqFiles) if (req.ucName !== null) addTo(filesOfUc, req.ucName, file);
  for (const { file, req, refs } of reqFiles) {
    if (req.ucName === null) {
      out.push({
        rule: "requirement-uc",
        file,
        target: "\u8868\u984C",
        detail: "\u8868\u984C\u304C\u300C# \u8981\u6C42\u7968: <UC \u540D>\u300D\u306E\u5F62\u3067\u8AAD\u3081\u305A\u3001UC \u540D\u3092\u53D6\u308C\u306A\u3044"
      });
    } else {
      const target = `UC:${req.ucName}`;
      if (!ucNames.has(req.ucName)) {
        out.push({
          rule: "requirement-uc",
          file,
          target,
          detail: `UC\u300E${req.ucName}\u300F\u304C\u8868\uFF08${tableById("use-case").file}\uFF09\u306B\u7121\u3044`
        });
      }
      const same = filesOfUc.get(req.ucName);
      if (same.length > 1) {
        out.push({
          rule: "requirement-uc",
          file,
          target,
          detail: `UC\u300E${req.ucName}\u300F\u306E\u8981\u6C42\u7968\u304C\u8907\u6570\u3042\u308B\uFF08${same.join("\u3001")}\uFF09`
        });
      }
    }
    for (const [i, line] of req.lines.entries()) {
      const lineTarget = `\u4ED5\u69D8:${line.ordinal}`;
      for (const ref of refs[i].refs) {
        const problem = referenceProblem(ref, ctx);
        if (problem !== null) {
          out.push({ rule: "requirement-reference", file, target: lineTarget, detail: `RDRA \u6B04\u306E${problem}` });
        }
        const part = nameInText(ref);
        if (part !== null && !line.text.includes(part)) {
          out.push({
            rule: "requirement-name-absent",
            file,
            target: lineTarget,
            detail: `RDRA \u6B04\u306E${ref.kind}\u300E${ref.name}\u300F\u306E\u540D\u524D\uFF08\u300E${part}\u300F\uFF09\u304C\u8981\u6C42\u6587\u306B\u73FE\u308C\u306A\u3044`
          });
        }
      }
    }
  }
  const ucDef = tableById("use-case");
  const useCaseOf = new Map(ctx.useCases.map((u) => [u.name, u]));
  if (reqFiles.length > 0) {
    for (const uc of ctx.useCases) {
      if (!uc.hypothesis && !filesOfUc.has(uc.name)) {
        missing.push({
          rule: "requirement-missing",
          file: ucDef.file,
          target: `UC:${uc.name}`,
          detail: `\u300E\u4EEE\u8AAC\u300F\u30AD\u30FC\u306E\u7121\u3044 UC \u306E\u8981\u6C42\u7968\u304C ${LAYOUT.requirements}/ \u306B\u7121\u3044`
        });
      }
    }
  }
  for (const { file, req, refs } of reqFiles) {
    if (req.ucName === null) continue;
    const uc = useCaseOf.get(req.ucName);
    if (uc === void 0 || uc.hypothesis) continue;
    const listed = /* @__PURE__ */ new Set();
    for (const l of refs) {
      for (const r of l.refs) if (r.kind !== null && r.name !== null) listed.add(refKey(r.kind, r.name));
    }
    for (const c of uc.conditions) {
      if (!listed.has(refKey("\u6761\u4EF6", c))) {
        missing.push({
          rule: "requirement-coverage",
          file,
          target: `\u6761\u4EF6:${c}`,
          detail: `UC\u300E${uc.name}\u300F\u306E\u6761\u4EF6\u300E${c}\u300F\u304C\u3001\u3069\u306E\u4ED5\u69D8\u306E\u884C\u306E RDRA \u6B04\u306B\u3082 \u6761\u4EF6\u300C${c}\u300D\u3068\u3057\u3066\u73FE\u308C\u306A\u3044`
        });
      }
    }
    for (const t of ctx.transitions) {
      if (t.uc !== uc.name) continue;
      const name = `${t.model}${REQUIREMENT_STATE_SEP}${t.next}`;
      if (!listed.has(refKey("\u72B6\u614B", name))) {
        missing.push({
          rule: "requirement-coverage",
          file,
          target: t.target,
          detail: `UC\u300E${uc.name}\u300F\u306E\u9077\u79FB\u5148\u72B6\u614B\u300E${name}\u300F\u304C\u3001\u3069\u306E\u4ED5\u69D8\u306E\u884C\u306E RDRA \u6B04\u306B\u3082 \u72B6\u614B\u300C${name}\u300D\u3068\u3057\u3066\u73FE\u308C\u306A\u3044`
        });
      }
    }
  }
  const features = [];
  let unreadable = false;
  for (const file of listFiles(root, LAYOUT.examples, ".feature")) {
    const parsed = parseExample(readFileSync2(join2(root, file), "utf8"));
    if (!parsed.ok) {
      unreadable = true;
      out.push({
        rule: "example-syntax",
        file,
        target: "\u69CB\u6587",
        detail: `Gherkin \u3068\u3057\u3066\u8AAD\u3081\u306A\u3044: ${parsed.message}`
      });
    } else if (parsed.feature === null) {
      out.push({ rule: "example-feature", file, target: "\u6A5F\u80FD", detail: "\u6A5F\u80FD\uFF08Feature\uFF09\u304C\u7121\u3044" });
    } else {
      features.push({ file, feature: parsed.feature });
    }
  }
  const featureFilesOfUc = /* @__PURE__ */ new Map();
  for (const { file, feature } of features) {
    if (feature.name !== "") addTo(featureFilesOfUc, feature.name, file);
  }
  for (const { file, feature } of features) {
    if (feature.name === "") {
      out.push({ rule: "example-feature", file, target: "\u6A5F\u80FD:\uFF08\u540D\u524D\u306A\u3057\uFF09", detail: "\u6A5F\u80FD\u306E\u540D\u524D\u304C\u7A7A" });
      continue;
    }
    const target = `\u6A5F\u80FD:${feature.name}`;
    if (!ucNames.has(feature.name)) {
      out.push({
        rule: "example-feature",
        file,
        target,
        detail: `\u6A5F\u80FD\u540D\u300E${feature.name}\u300F\u304C UC \u306E\u8868\uFF08${ucDef.file}\uFF09\u306B\u7121\u3044`
      });
    }
    const same = featureFilesOfUc.get(feature.name);
    if (same.length > 1) {
      out.push({
        rule: "example-feature",
        file,
        target,
        detail: `UC\u300E${feature.name}\u300F\u306E\u6A5F\u80FD\u304C\u8907\u6570\u306E\u30D5\u30A1\u30A4\u30EB\u306B\u3042\u308B\uFF08${same.join("\u3001")}\uFF09`
      });
    }
  }
  const sentencesOfUc = /* @__PURE__ */ new Map();
  for (const { req } of reqFiles) {
    if (req.ucName === null) continue;
    if (!sentencesOfUc.has(req.ucName)) sentencesOfUc.set(req.ucName, /* @__PURE__ */ new Set());
    for (const l of req.lines) sentencesOfUc.get(req.ucName).add(l.text);
  }
  const rulesOfUc = /* @__PURE__ */ new Map();
  for (const { feature } of features) {
    if (feature.name === "") continue;
    if (!rulesOfUc.has(feature.name)) rulesOfUc.set(feature.name, /* @__PURE__ */ new Set());
    for (const r of feature.rules) rulesOfUc.get(feature.name).add(r.name);
  }
  for (const { file, feature } of features) {
    const sentences = sentencesOfUc.get(feature.name);
    for (const r of feature.rules) {
      if (sentences === void 0) {
        out.push({
          rule: "example-rule-mismatch",
          file,
          target: `\u30EB\u30FC\u30EB:${r.name}`,
          detail: `UC\u300E${feature.name}\u300F\u306E\u8981\u6C42\u7968\u304C\u7121\u304F\u3001\u30EB\u30FC\u30EB\u306E\u540D\u524D\u306B\u5BFE\u5FDC\u3059\u308B\u8981\u6C42\u6587\u304C\u7121\u3044`
        });
      } else if (!sentences.has(r.name)) {
        out.push({
          rule: "example-rule-mismatch",
          file,
          target: `\u30EB\u30FC\u30EB:${r.name}`,
          detail: `\u30EB\u30FC\u30EB\u306E\u540D\u524D\u304C\u3001UC\u300E${feature.name}\u300F\u306E\u8981\u6C42\u7968\u306E\u4ED5\u69D8\u306E\u884C\u306E\u8981\u6C42\u6587\u306E\u3069\u308C\u3068\u3082\u4E00\u81F4\u3057\u306A\u3044`
        });
      }
    }
    for (const s of feature.looseScenarios) {
      out.push({
        rule: "example-rule-mismatch",
        file,
        target: `\u30B7\u30CA\u30EA\u30AA:${s.name}`,
        detail: "\u30B7\u30CA\u30EA\u30AA\u304C\u30EB\u30FC\u30EB\u306E\u5916\uFF08\u6A5F\u80FD\u306E\u76F4\u4E0B\uFF09\u306B\u7F6E\u304B\u308C\u3066\u3044\u308B"
      });
    }
  }
  if (!unreadable) {
    for (const { file, req } of reqFiles) {
      if (req.ucName === null) continue;
      const rules = rulesOfUc.get(req.ucName);
      for (const l of req.lines) {
        if (rules?.has(l.text)) continue;
        missing.push({
          rule: "example-missing",
          file,
          target: `\u4ED5\u69D8:${l.ordinal}`,
          detail: rules === void 0 ? `UC\u300E${req.ucName}\u300F\u306E\u6A5F\u80FD\u304C ${LAYOUT.examples}/ \u306B\u7121\u304F\u3001\u8981\u6C42\u6587\u306B\u5BFE\u5FDC\u3059\u308B\u30EB\u30FC\u30EB\u304C\u7121\u3044` : `\u540C\u3058 UC \u306E\u6A5F\u80FD\u306B\u3001\u8981\u6C42\u6587\u3068\u540C\u3058\u540D\u524D\u306E\u30EB\u30FC\u30EB\u304C\u7121\u3044`
        });
      }
    }
  }
  for (const { file, feature } of features) {
    for (const r of feature.rules) {
      const count = r.scenarios.reduce((n, s) => n + s.expansions.length, 0);
      if (count > EXAMPLE_LIMIT) {
        out.push({
          rule: "example-limit",
          file,
          target: `\u30EB\u30FC\u30EB:${r.name}`,
          detail: `\u4F8B\u304C ${count} \u4EF6\u3067\u4E0A\u9650 ${EXAMPLE_LIMIT} \u4EF6\u3092\u8D85\u3048\u308B\uFF08\u898F\u5247\u304C\u675F\u306B\u306A\u3063\u3066\u3044\u308B\u3002\u8981\u6C42\u6587\u3092\u5206\u3051\u308B\uFF09`
        });
      }
    }
    const all = [...feature.looseScenarios, ...feature.rules.flatMap((r) => r.scenarios)].sort(
      (a, b) => a.line - b.line
    );
    const seen = /* @__PURE__ */ new Map();
    for (const s of all) {
      for (const e of s.expansions) {
        if (e.steps.length === 0) continue;
        const key = JSON.stringify(e.steps);
        const first = seen.get(key);
        if (first === void 0) {
          seen.set(key, `\u300E${s.name}${e.label}\u300F\uFF08${s.line}\u884C\u76EE\uFF09`);
        } else {
          out.push({
            rule: "example-duplicate",
            file,
            target: `\u30B7\u30CA\u30EA\u30AA:${s.name}${e.label}`,
            detail: `\u624B\u9806\u306E\u6587\u306E\u4E26\u3073\u304C${first}\u3068\u540C\u3058`
          });
        }
      }
    }
  }
  return { checked: out, docMissing: missing };
}

// src/check.ts
function formatViolation(v) {
  return `[${v.rule}] ${v.file} ${v.target}: ${v.detail}`;
}
function isMap(v) {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}
function typeOk(v, type, emptyOk) {
  if (emptyOk && (v === null || v === "")) return true;
  if (type === "string") return typeof v === "string";
  return Array.isArray(v) && v.every((x) => typeof x === "string");
}
function typeLabel(type) {
  return type === "string" ? "\u6587\u5B57\u5217" : "\u6587\u5B57\u5217\u306E\u4E26\u3073";
}
function stateTarget(model, state) {
  return `\u72B6\u614B:${model}\uFF0F${state === "" ? "\uFF08\u521D\u671F\uFF09" : state}`;
}
function one(row, key) {
  const v = row.data[key];
  return typeof v === "string" ? v.trim() : "";
}
function values(row, key) {
  const v = row.data[key];
  if (typeof v === "string") {
    if (row.def.splitKeys.includes(key)) {
      return v.split("\u3001").map((s) => s.trim()).filter((s) => s !== "");
    }
    return v.trim() === "" ? [] : [v.trim()];
  }
  if (Array.isArray(v)) {
    return v.filter((x) => typeof x === "string" && x.trim() !== "").map((x) => x.trim());
  }
  return [];
}
function loadTable(root, def, out) {
  const path = join3(root, def.file);
  if (!existsSync3(path)) return [];
  const tableTarget = `\u8868:${basename(def.file)}`;
  const doc = (0, import_yaml.parseDocument)(readFileSync3(path, "utf8"));
  if (doc.errors.length > 0) {
    const msg = doc.errors[0].message.split("\n")[0];
    out.push({ rule: "invalid-shape", file: def.file, target: tableTarget, detail: `YAML \u306E\u69CB\u6587\u8AA4\u308A: ${msg}` });
    return [];
  }
  const data = doc.toJS();
  if (data === null || data === void 0) return [];
  if (!Array.isArray(data)) {
    out.push({
      rule: "invalid-shape",
      file: def.file,
      target: tableTarget,
      detail: "\u30C8\u30C3\u30D7\u30EC\u30D9\u30EB\u304C\u30EC\u30B3\u30FC\u30C9\u306E\u4E26\u3073\uFF08\u30B7\u30FC\u30B1\u30F3\u30B9\uFF09\u306B\u306A\u3063\u3066\u3044\u306A\u3044"
    });
    return [];
  }
  const rows = [];
  data.forEach((item, i) => {
    const ordinal = `#${i + 1}`;
    if (!isMap(item)) {
      out.push({
        rule: "invalid-shape",
        file: def.file,
        target: `${def.kind}:${ordinal}`,
        detail: `${i + 1}\u756A\u76EE\u306E\u30EC\u30B3\u30FC\u30C9\u304C\u30DE\u30C3\u30D7\u306B\u306A\u3063\u3066\u3044\u306A\u3044`
      });
      return;
    }
    const nameVal = item[def.nameKey];
    const hasName = typeof nameVal === "string" && nameVal.trim() !== "";
    const name = hasName ? nameVal.trim() : "";
    let target = `${def.kind}:${hasName ? name : ordinal}`;
    if (def.id === "state" && hasName) {
      const st = typeof item["\u72B6\u614B"] === "string" ? item["\u72B6\u614B"].trim() : "";
      target = stateTarget(name, st);
    }
    if (!hasName) {
      out.push({
        rule: "invalid-shape",
        file: def.file,
        target,
        detail: `\u540D\u524D\u30AD\u30FC\u300E${def.nameKey}\u300F\u304C\u7121\u3044\u3001\u307E\u305F\u306F\u7A7A\u30FB\u6587\u5B57\u5217\u3067\u306A\u3044`
      });
    }
    for (const [key, value] of Object.entries(item)) {
      const type = def.keys[key];
      if (type === void 0) {
        out.push({ rule: "unknown-key", file: def.file, target, detail: `\u8A31\u3055\u308C\u306A\u3044\u30AD\u30FC\u300E${key}\u300F` });
        continue;
      }
      if (key === def.nameKey) continue;
      if (!typeOk(value, type, def.emptyOkKeys.includes(key))) {
        out.push({
          rule: "invalid-shape",
          file: def.file,
          target,
          detail: `\u30AD\u30FC\u300E${key}\u300F\u306E\u5024\u304C${typeLabel(type)}\u306B\u306A\u3063\u3066\u3044\u306A\u3044`
        });
      }
    }
    if (hasName) rows.push({ def, data: item, name });
  });
  return rows;
}
function rowTarget(row) {
  if (row.def.id === "state") return stateTarget(row.name, one(row, "\u72B6\u614B"));
  return `${row.def.kind}:${row.name}`;
}
function loadTables(root, out) {
  const rows = {};
  for (const def of TABLES) rows[def.id] = loadTable(root, def, out);
  return rows;
}
function traceContext(rows) {
  const traceNames = /* @__PURE__ */ new Map();
  for (const def of TABLES) if (def.id !== "state") traceNames.set(def.kind, new Set(rows[def.id].map((r) => r.name)));
  traceNames.set("\u72B6\u614B\u30E2\u30C7\u30EB", new Set(rows["state"].map((r) => r.name)));
  const stateNamesOf = /* @__PURE__ */ new Map();
  const transitions = [];
  for (const r of rows["state"]) {
    if (!stateNamesOf.has(r.name)) stateNamesOf.set(r.name, /* @__PURE__ */ new Set());
    const next = one(r, "\u9077\u79FB\u5148\u72B6\u614B");
    for (const st of [one(r, "\u72B6\u614B"), next]) if (st !== "") stateNamesOf.get(r.name).add(st);
    const uc = one(r, "\u9077\u79FBUC");
    if (uc !== "" && next !== "") transitions.push({ model: r.name, uc, next, target: stateTarget(r.name, next) });
  }
  return {
    useCases: rows["use-case"].map((r) => ({
      name: r.name,
      hypothesis: Object.hasOwn(r.data, "\u4EEE\u8AAC"),
      conditions: values(r, "\u6761\u4EF6")
    })),
    names: traceNames,
    statesOf: stateNamesOf,
    transitions
  };
}
function checkDocMissing(root) {
  return checkTrace(root, traceContext(loadTables(root, []))).docMissing;
}
function checkRepo(root) {
  const out = [];
  const rows = loadTables(root, out);
  const names = {};
  for (const def of TABLES) names[def.id] = new Set(rows[def.id].map((r) => r.name));
  const models = names["state"];
  const statesOf = /* @__PURE__ */ new Map();
  for (const r of rows["state"]) {
    const st = one(r, "\u72B6\u614B");
    if (st === "") continue;
    if (!statesOf.has(r.name)) statesOf.set(r.name, /* @__PURE__ */ new Set());
    statesOf.get(r.name).add(st);
  }
  const has = (id) => (v) => names[id].has(v);
  const refSpecs = [
    { from: "use-case", key: "\u30A2\u30AF\u30BF\u30FC", toKind: "\u30A2\u30AF\u30BF\u30FC", exists: has("actor") },
    { from: "use-case", key: "\u5916\u90E8\u30B7\u30B9\u30C6\u30E0", toKind: "\u5916\u90E8\u30B7\u30B9\u30C6\u30E0", exists: has("external-system") },
    { from: "use-case", key: "\u60C5\u5831", toKind: "\u60C5\u5831", exists: has("information") },
    { from: "use-case", key: "\u6761\u4EF6", toKind: "\u6761\u4EF6", exists: has("condition") },
    { from: "information", key: "\u95A2\u9023\u60C5\u5831", toKind: "\u60C5\u5831", exists: has("information") },
    { from: "information", key: "\u72B6\u614B\u30E2\u30C7\u30EB", toKind: "\u72B6\u614B\u30E2\u30C7\u30EB", exists: (v) => models.has(v) },
    { from: "information", key: "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3", toKind: "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3", exists: has("variation") },
    { from: "state", key: "\u9077\u79FBUC", toKind: "UC", exists: has("use-case") },
    {
      from: "state",
      key: "\u9077\u79FB\u5148\u72B6\u614B",
      toKind: "\u540C\u3058\u72B6\u614B\u30E2\u30C7\u30EB\u306E\u72B6\u614B",
      exists: (v, row) => statesOf.get(row.name)?.has(v) ?? false
    },
    { from: "condition", key: "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3", toKind: "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3", exists: has("variation") },
    { from: "condition", key: "\u72B6\u614B\u30E2\u30C7\u30EB", toKind: "\u72B6\u614B\u30E2\u30C7\u30EB", exists: (v) => models.has(v) }
  ];
  for (const spec of refSpecs) {
    const def = tableById(spec.from);
    for (const row of rows[spec.from]) {
      for (const v of values(row, spec.key)) {
        if (!spec.exists(v, row)) {
          out.push({
            rule: "undefined-reference",
            file: def.file,
            target: rowTarget(row),
            detail: `${spec.key}\u300E${v}\u300F\u304C\u5B9A\u7FA9\u3055\u308C\u3066\u3044\u306A\u3044\uFF08${spec.toKind}\uFF09`
          });
        }
      }
    }
  }
  const connectSpecs = [
    ["actor", "\u30A2\u30AF\u30BF\u30FC"],
    ["external-system", "\u5916\u90E8\u30B7\u30B9\u30C6\u30E0"],
    ["information", "\u60C5\u5831"],
    ["condition", "\u6761\u4EF6"]
  ];
  for (const [id, ucKey] of connectSpecs) {
    const referenced = /* @__PURE__ */ new Set();
    for (const uc of rows["use-case"]) for (const v of values(uc, ucKey)) referenced.add(v);
    const def = tableById(id);
    for (const row of rows[id]) {
      if (!referenced.has(row.name)) {
        out.push({
          rule: "unconnected",
          file: def.file,
          target: rowTarget(row),
          detail: `\u3069\u306E UC \u306E\u300C${ucKey}\u300D\u304B\u3089\u3082\u53C2\u7167\u3055\u308C\u3066\u3044\u306A\u3044`
        });
      }
    }
  }
  for (const def of TABLES) {
    const seen = /* @__PURE__ */ new Set();
    const reported = /* @__PURE__ */ new Set();
    for (const row of rows[def.id]) {
      const key = def.id === "state" ? JSON.stringify([row.name, one(row, "\u72B6\u614B"), one(row, "\u9077\u79FBUC")]) : row.name;
      if (seen.has(key) && !reported.has(key)) {
        reported.add(key);
        out.push({
          rule: "duplicate-name",
          file: def.file,
          target: rowTarget(row),
          detail: def.id === "state" ? `\uFF08\u72B6\u614B\u30E2\u30C7\u30EB, \u72B6\u614B, \u9077\u79FBUC\uFF09\u306E\u7D44\u300E${row.name}\uFF0F${one(row, "\u72B6\u614B")}\uFF0F${one(row, "\u9077\u79FBUC")}\u300F\u304C\u91CD\u8907\u3057\u3066\u3044\u308B` : `\u540D\u524D\u300E${row.name}\u300F\u304C\u91CD\u8907\u3057\u3066\u3044\u308B`
        });
      }
      seen.add(key);
    }
  }
  out.push(...checkTrace(root, traceContext(rows)).checked);
  return out;
}

// src/render.ts
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join as join5 } from "node:path";

// src/html.ts
var MERMAID_URL = "https://cdn.jsdelivr.net/npm/mermaid@11.4.1/dist/mermaid.esm.min.mjs";
var UNKNOWN_MARK = "\u26A0";
var HIGHLIGHT = "stroke:#d9480f,stroke-width:3px,color:#d9480f";
var DIMMED = "stroke:#adb5bd,color:#868e96";
function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}
function mermaidText(s) {
  return s.replace(/#/g, "#35;").replace(/&/g, "#amp;").replace(/"/g, "#quot;").replace(/</g, "#lt;").replace(/>/g, "#gt;").replace(/`/g, "#96;").replace(/\s+/g, " ");
}
function marked(name, known) {
  return known ? name : `${UNKNOWN_MARK} ${name}`;
}
function stateChart(model, highlightUc) {
  const id = new Map(model.states.map((s, i) => [s, `s${i}`]));
  const out = ["flowchart LR"];
  const drawn = model.transitions.filter((t) => t.from !== null || t.to !== null);
  if (drawn.some((t) => t.from === null)) out.push('  start0(("\u958B\u59CB")):::terminal');
  for (const s of model.states) {
    const known = !model.transitions.some((t) => t.to === s && !t.toKnown);
    out.push(`  ${id.get(s)}["${mermaidText(marked(s, known))}"]`);
  }
  if (drawn.some((t) => t.to === null)) out.push('  end0(("\u7D42\u7AEF")):::terminal');
  const styles = [];
  drawn.forEach((t, i) => {
    const from = t.from === null ? "start0" : id.get(t.from);
    const to = t.to === null ? "end0" : id.get(t.to);
    const arrow = t.hypothesis ? "-.->" : "-->";
    const label = t.uc === null ? "" : `|"${mermaidText(marked(t.uc, t.ucKnown))}"|`;
    out.push(`  ${from} ${arrow}${label} ${to}`);
    if (highlightUc !== null) {
      const dash = t.hypothesis ? ",stroke-dasharray:5 5" : "";
      styles.push(`  linkStyle ${i} ${t.uc === highlightUc ? HIGHLIGHT : DIMMED}${dash}`);
    }
  });
  out.push(...styles);
  out.push("  classDef terminal fill:#495057,stroke:#495057,color:#fff");
  return out.join("\n");
}
function chartBlock(model, highlightUc) {
  return `<pre class="mermaid">${escapeHtml(stateChart(model, highlightUc))}</pre>`;
}
function nameHtml(n) {
  return n.known ? escapeHtml(n.name) : `<span class="unknown" title="\u8868\u306B\u7121\u3044\u540D\u524D">${escapeHtml(marked(n.name, false))}</span>`;
}
function ucLink(name, known, view) {
  if (name === null) return "";
  const uc = view.useCases.find((u) => u.name === name);
  if (uc === void 0) return nameHtml({ name, known });
  return `<a href="#${uc.anchor}">${escapeHtml(name)}</a>`;
}
function hypothesisBadge(h) {
  if (h === null) return "";
  const ids = h.length > 0 ? `: ${escapeHtml(h.join("\u3001"))}` : "";
  return `<span class="badge">\u4EEE\u8AAC${ids}</span>`;
}
function scenarioList(scenarios) {
  const items = scenarios.map(
    (s) => `<li>${escapeHtml(s.name)}${s.count === 1 ? "" : `<span class="note">\uFF08${s.count} \u4EF6\uFF09</span>`}</li>`
  );
  return `<ul class="scenarios">${items.join("")}</ul>`;
}
function stateModelSection(model, view) {
  const rows = model.transitions.map((t) => {
    const from = t.from === null ? '<span class="note">\uFF08\u958B\u59CB\uFF09</span>' : escapeHtml(t.from);
    const to = t.to === null ? '<span class="note">\uFF08\u7D42\u7AEF\uFF09</span>' : nameHtml({ name: t.to, known: t.toKnown });
    return `<tr><td>${from}</td><td>${to}</td><td>${ucLink(t.uc, t.ucKnown, view)}</td><td>${escapeHtml(t.description)}</td><td>${t.hypothesis ? "\u4EEE\u8AAC" : ""}</td></tr>`;
  });
  return `<h3>${escapeHtml(model.name)}</h3>
${chartBlock(model, null)}
<table><thead><tr><th>\u5143\u306E\u72B6\u614B</th><th>\u9077\u79FB\u5148</th><th>\u9077\u79FB UC</th><th>\u8AAC\u660E</th><th>\u4EEE\u8AAC</th></tr></thead>
<tbody>${rows.join("\n")}</tbody></table>`;
}
function presence(n, unit) {
  return n === 0 ? '<span class="missing">\u7121\u3044</span>' : `\u3042\u308A\uFF08${n} ${unit}\uFF09`;
}
function useCaseIndex(view) {
  const rows = view.useCases.map((uc) => {
    const lines = uc.requirements.reduce((n, r) => n + r.lines.length, 0);
    const scenarios = uc.requirements.reduce((n, r) => n + r.lines.reduce((m, l) => m + l.scenarios.length, 0), 0) + uc.unlinkedRules.reduce((n, r) => n + r.scenarios.length, 0) + uc.looseScenarios.length;
    return `<tr><td><a href="#${uc.anchor}">${escapeHtml(uc.name)}</a></td><td>${uc.actors.map(nameHtml).join("\u3001")}</td><td>${hypothesisBadge(uc.hypothesis)}</td><td>${uc.requirements.length === 0 ? presence(0, "") : presence(lines, "\u884C")}</td><td>${uc.exampleFiles.length === 0 ? presence(0, "") : presence(scenarios, "\u30B7\u30CA\u30EA\u30AA")}</td></tr>`;
  });
  return `<table><thead><tr><th>UC</th><th>\u30A2\u30AF\u30BF\u30FC</th><th>\u4EEE\u8AAC</th><th>\u8981\u6C42\u7968</th><th>\u4F8B</th></tr></thead>
<tbody>${rows.join("\n")}</tbody></table>`;
}
function definedReferences(line) {
  const seen = /* @__PURE__ */ new Set();
  return line.references.filter((r) => {
    if (r.definition === null || r.name === null || seen.has(r.name)) return false;
    seen.add(r.name);
    return true;
  });
}
function definitionTitle(r) {
  const d = r.definition;
  const extra = [
    d.values.length > 0 ? `\u5024: ${d.values.join("\u3001")}` : "",
    d.attributes.length > 0 ? `\u5C5E\u6027: ${d.attributes.join("\u3001")}` : ""
  ].filter((x) => x !== "");
  return extra.length > 0 ? `${d.description}\uFF08${extra.join("\u3002")}\uFF09` : d.description;
}
function sentenceHtml(line, tableNames) {
  const refs = definedReferences(line);
  if (refs.length === 0) return escapeHtml(line.text);
  const byName = new Map(refs.map((r) => [r.name, r]));
  const names = [.../* @__PURE__ */ new Set([...tableNames, ...byName.keys()])].sort((a, b) => b.length - a.length);
  const pattern = new RegExp(names.map((n) => n.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("|"), "g");
  let out = "";
  let last = 0;
  for (const m of line.text.matchAll(pattern)) {
    const ref = byName.get(m[0]);
    if (ref === void 0) continue;
    out += escapeHtml(line.text.slice(last, m.index));
    out += `<span class="term" tabindex="0" data-tip="${escapeHtml(definitionTitle(ref))}">${escapeHtml(m[0])}</span>`;
    last = m.index + m[0].length;
  }
  return out + escapeHtml(line.text.slice(last));
}
function definitionsHtml(line) {
  const refs = definedReferences(line);
  const items = refs.map((r) => {
    const d = r.definition;
    const values2 = d.values.length > 0 ? `<div class="sub">\u5024: ${escapeHtml(d.values.join("\u3001"))}</div>` : "";
    const attributes = d.attributes.length > 0 ? `<div class="sub">\u5C5E\u6027: ${escapeHtml(d.attributes.join("\u3001"))}</div>` : "";
    const variations = d.variations.map(
      (v) => `<div class="sub">${nameHtml(v)}${v.values.length > 0 ? `: ${escapeHtml(v.values.join("\u3001"))}` : ""}</div>`
    ).join("");
    return `<li><span class="kind">${escapeHtml(r.kind ?? "")}</span><strong>${escapeHtml(r.name)}</strong>: ${escapeHtml(d.description)}${values2}${attributes}${variations}</li>`;
  });
  if (items.length === 0) return "";
  return `<div class="defs" hidden><ul>${items.join("")}</ul></div>`;
}
function requirementBlock(uc, view) {
  if (uc.requirements.length === 0) {
    const why = uc.hypothesis !== null ? "\uFF08\u4EEE\u8AAC\u306E UC\u3002\u691C\u67FB\u306F\u8981\u6C42\u7968\u3092\u6C42\u3081\u306A\u3044\uFF09" : "";
    return `<p class="missing">\u8981\u6C42\u7968\u304C\u7121\u3044${why}</p>`;
  }
  return uc.requirements.map((r) => {
    const lines = r.lines.map((l) => {
      const refs = l.references.map(
        (ref) => ref.known ? escapeHtml(ref.raw) : `<span class="unknown" title="\u8868\u306B\u7121\u3044\u3001\u307E\u305F\u306F\u8AAD\u3081\u306A\u3044\u53C2\u7167">${escapeHtml(marked(ref.raw, false))}</span>`
      ).join("\u3001");
      const examples = l.scenarios.length > 0 ? scenarioList(l.scenarios) : uc.exampleFiles.length > 0 ? '<p class="missing">\u3053\u306E\u884C\u306B\u7D50\u3073\u4ED8\u304F\u4F8B\u304C\u7121\u3044</p>' : "";
      return `<li><p class="sentence">${sentenceHtml(l, view.tableNames)}</p>
${definitionsHtml(l)}
<dl class="fields"><dt>\u7406\u7531</dt><dd>${escapeHtml(l.reason ?? "\uFF08\u6B04\u304C\u7121\u3044\uFF09")}</dd><dt>RDRA</dt><dd>${refs === "" ? "\u306A\u3057" : refs}</dd></dl>
${examples}</li>`;
    });
    const reason = r.reason === null ? "\uFF08\u7BC0\u304C\u7121\u3044\uFF09" : escapeHtml(r.reason).replace(/\n/g, "<br>");
    return `<p class="file">${escapeHtml(r.file)}</p>
<p><strong>\u7406\u7531:</strong> ${reason}</p>
<ol class="lines">${lines.join("\n")}</ol>`;
  }).join("\n");
}
function exampleBlock(uc) {
  const parts = [];
  if (uc.exampleFiles.length === 0) {
    parts.push('<p class="missing">\u4F8B\u304C\u7121\u3044</p>');
  } else {
    parts.push(`<p class="file">${uc.exampleFiles.map(escapeHtml).join("\u3001")}</p>`);
  }
  if (uc.unlinkedRules.length > 0 || uc.looseScenarios.length > 0) {
    const rules = uc.unlinkedRules.map(
      (r) => `<li><p class="sentence">\u30EB\u30FC\u30EB: ${escapeHtml(r.name)}</p>${scenarioList(r.scenarios)}</li>`
    );
    if (uc.looseScenarios.length > 0) {
      rules.push(`<li><p class="sentence">\u30EB\u30FC\u30EB\u306E\u5916\u306E\u30B7\u30CA\u30EA\u30AA</p>${scenarioList(uc.looseScenarios)}</li>`);
    }
    parts.push(`<div class="unlinked"><h4>\u8981\u6C42\u7968\u306E\u884C\u306B\u7D50\u3073\u4ED8\u304B\u306A\u3044\u4F8B</h4><ul>${rules.join("\n")}</ul></div>`);
  }
  return parts.join("\n");
}
function sliceSection(uc, view) {
  const roles = (xs) => xs.map((x) => `<li>${nameHtml(x)}${x.role === "" ? "" : `\uFF08${escapeHtml(x.role)}\uFF09`}</li>`).join("");
  const charts = uc.stateModels.length === 0 ? '<p class="note">\u3053\u306E UC \u304C\u52D5\u304B\u3059\u9077\u79FB\u306F\u7121\u3044</p>' : uc.stateModels.map((name) => view.stateModels.find((m) => m.name === name)).map((m) => `<p class="caption">${escapeHtml(m.name)}</p>${chartBlock(m, uc.name)}`).join("\n");
  const information = uc.information.length === 0 ? '<p class="note">\u306A\u3057</p>' : `<table><thead><tr><th>\u60C5\u5831</th><th>\u8AAC\u660E</th><th>\u5C5E\u6027</th></tr></thead><tbody>${uc.information.map(
    (i) => `<tr><td>${nameHtml(i)}</td><td>${escapeHtml(i.description)}</td><td>${escapeHtml(i.attributes.join("\u3001"))}</td></tr>`
  ).join("")}</tbody></table>`;
  const conditions = uc.conditions.length === 0 ? '<p class="note">\u306A\u3057</p>' : `<table><thead><tr><th>\u6761\u4EF6</th><th>\u6761\u4EF6\u306E\u8AAC\u660E</th><th>\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3</th></tr></thead><tbody>${uc.conditions.map((c) => {
    const vs = c.variations.map(
      (v) => `<div>${nameHtml(v)}${v.values.length > 0 ? `: ${escapeHtml(v.values.join("\u3001"))}` : ""}</div>`
    ).join("");
    return `<tr><td>${nameHtml(c)}</td><td>${escapeHtml(c.description)}</td><td>${vs}</td></tr>`;
  }).join("")}</tbody></table>`;
  return `<section class="slice" id="${uc.anchor}">
<h2>${escapeHtml(uc.name)} ${hypothesisBadge(uc.hypothesis)}</h2>
<p>${escapeHtml(uc.description)}</p>
<div class="cols">
<div><h4>\u30A2\u30AF\u30BF\u30FC</h4>${uc.actors.length === 0 ? '<p class="note">\u306A\u3057</p>' : `<ul>${roles(uc.actors)}</ul>`}</div>
<div><h4>\u5916\u90E8\u30B7\u30B9\u30C6\u30E0</h4>${uc.externalSystems.length === 0 ? '<p class="note">\u306A\u3057</p>' : `<ul>${roles(uc.externalSystems)}</ul>`}</div>
</div>
<h3>\u72B6\u614B\u306E\u9077\u79FB</h3>
${charts}
<h3>\u60C5\u5831</h3>
${information}
<h3>\u6761\u4EF6</h3>
${conditions}
<h3>\u8981\u6C42\u7968</h3>
${requirementBlock(uc, view)}
<h3>\u4F8B</h3>
${exampleBlock(uc)}
<p class="top"><a href="#top">\u5148\u982D\u3078</a></p>
</section>`;
}
function strayBlock(view) {
  const items = [
    ...view.strayRequirements.map(
      (r) => `<li>\u8981\u6C42\u7968 ${escapeHtml(r.file)}: ${r.ucName === null ? "\u8868\u984C\u304B\u3089 UC \u540D\u3092\u8AAD\u3081\u306A\u3044" : `UC\u300E${nameHtml({ name: r.ucName, known: false })}\u300F\u304C UC \u306E\u8868\u306B\u7121\u3044`}</li>`
    ),
    ...view.strayExamples.map(
      (e) => `<li>\u4F8B ${escapeHtml(e.file)}: ${e.name === "" ? "\u6A5F\u80FD\u306E\u540D\u524D\u304C\u7A7A" : `\u6A5F\u80FD\u540D\u300E${nameHtml({ name: e.name, known: false })}\u300F\u304C UC \u306E\u8868\u306B\u7121\u3044`}</li>`
    ),
    ...view.unreadableExamples.map((e) => `<li>\u4F8B ${escapeHtml(e.file)}: \u8AAD\u3081\u306A\u3044\uFF08${escapeHtml(e.message)}\uFF09</li>`)
  ];
  if (items.length === 0) return "";
  return `<section id="stray"><h2>\u3069\u306E UC \u306B\u3082\u7D50\u3073\u4ED8\u304B\u306A\u3044\u8981\u6C42\u7968\u30FB\u4F8B</h2><ul>${items.join("\n")}</ul></section>`;
}
function timestamp(d) {
  const p = (n) => String(n).padStart(2, "0");
  const offset = -d.getTimezoneOffset();
  const sign = offset >= 0 ? "+" : "-";
  const tz = `${sign}${p(Math.floor(Math.abs(offset) / 60))}:${p(Math.abs(offset) % 60)}`;
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())} ${tz}`;
}
var STYLE = `
:root { --fg:#212529; --bg:#ffffff; --muted:#6c757d; --line:#dee2e6; --panel:#f8f9fa; --warn:#c92a2a; --accent:#1c7ed6; --tip-bg:#343a40; --tip-fg:#f8f9fa; }
@media (prefers-color-scheme: dark) {
  :root { --fg:#e9ecef; --bg:#1e1f22; --muted:#adb5bd; --line:#3a3d42; --panel:#26282c; --warn:#ff8787; --accent:#74c0fc; --tip-bg:#f1f3f5; --tip-fg:#212529; }
}
body { margin:0; padding:16px 24px 48px; color:var(--fg); background:var(--bg); font:15px/1.6 system-ui, sans-serif; }
a { color:var(--accent); }
header { border-bottom:1px solid var(--line); margin-bottom:16px; }
header p { margin:4px 0; color:var(--muted); font-size:13px; }
nav a { margin-right:12px; }
table { border-collapse:collapse; margin:8px 0 16px; width:100%; }
th, td { border:1px solid var(--line); padding:4px 8px; text-align:left; vertical-align:top; }
th { background:var(--panel); }
pre.mermaid { background:#fff; border:1px solid var(--line); border-radius:6px; padding:8px; overflow-x:auto; }
section.slice { border-top:2px solid var(--line); margin-top:32px; padding-top:8px; }
.cols { display:flex; gap:32px; flex-wrap:wrap; }
.badge { display:inline-block; font-size:12px; padding:1px 8px; border-radius:10px; background:#fff3bf; color:#5c3c00; vertical-align:middle; }
.unknown { color:var(--warn); font-weight:600; }
.missing { color:var(--warn); }
.note, .file, .caption { color:var(--muted); font-size:13px; }
ol.lines > li { margin-bottom:12px; }
.sentence { margin:0; font-weight:600; }
dl.fields { display:grid; grid-template-columns:max-content 1fr; gap:0 8px; margin:4px 0; font-size:13px; }
dl.fields dt { color:var(--muted); }
dl.fields dd { margin:0; }
ul.scenarios { margin:4px 0; padding-left:20px; font-size:13px; }
ul.scenarios li::marker { content:'\u25B8 '; }
.term { border-bottom:2px dotted var(--accent); cursor:help; }
.term { position:relative; }
.term:hover::after, .term:focus::after {
  content:attr(data-tip); position:absolute; left:0; top:100%; z-index:10; margin-top:4px;
  width:max-content; max-width:min(32em, 80vw); white-space:normal; font-weight:normal; font-size:13px; line-height:1.5;
  padding:6px 10px; border-radius:6px; background:var(--tip-bg); color:var(--tip-fg); box-shadow:0 2px 8px rgba(0,0,0,.25);
}
div.defs { margin:2px 0 4px; font-size:13px; }
div.defs ul { list-style:none; margin:4px 0; padding:6px 10px; background:var(--panel); border-left:3px solid var(--accent); }
div.defs li + li { margin-top:4px; }
div.defs .kind { color:var(--muted); margin-right:6px; }
div.defs .sub { color:var(--muted); padding-left:1em; }
nav button { font-size:12px; margin-left:4px; }
.unlinked { border:1px dashed var(--warn); border-radius:6px; padding:4px 12px; margin:8px 0; }
.top { text-align:right; font-size:13px; }
`;
function renderHtml(view, generatedAt) {
  const models = view.stateModels.length === 0 ? '<p class="note">\u72B6\u614B\u306E\u8868\u306B\u72B6\u614B\u30E2\u30C7\u30EB\u304C\u7121\u3044</p>' : view.stateModels.map((m) => stateModelSection(m, view)).join("\n");
  const stray = strayBlock(view);
  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RDRA \u306E\u8A2D\u8A08\u306E\u53EF\u8996\u5316</title>
<style>${STYLE}</style>
</head>
<body id="top">
<header>
<h1>RDRA \u306E\u8A2D\u8A08\u306E\u53EF\u8996\u5316</h1>
<p>\u751F\u6210\u6642\u523B: ${escapeHtml(timestamp(generatedAt))}</p>
<p>\u6839: ${escapeHtml(view.root)}</p>
<nav><a href="#states">\u72B6\u614B\u9077\u79FB\u56F3</a><a href="#use-cases">UC \u306E\u4E00\u89A7</a>${stray === "" ? "" : '<a href="#stray">\u7D50\u3073\u4ED8\u304B\u306A\u3044\u8981\u6C42\u7968\u30FB\u4F8B</a>'}
\u8981\u6C42\u306E\u884C\u306E\u4E2D\u8EAB\uFF08\u540D\u524D\u306E\u30AF\u30EA\u30C3\u30AF\u3067\u3082\u958B\u9589\uFF09: <button type="button" data-defs="open">\u3059\u3079\u3066\u958B\u304F</button><button type="button" data-defs="close">\u3059\u3079\u3066\u9589\u3058\u308B</button></nav>
</header>
<section id="states"><h2>\u72B6\u614B\u9077\u79FB\u56F3</h2>
<p class="note">\u5B9F\u7DDA\u306F\u4E8B\u5B9F\u3001\u7834\u7DDA\u306F\u4EEE\u8AAC\u306E\u9077\u79FB\u3002${UNKNOWN_MARK} \u306F\u8868\u306B\u7121\u3044\u540D\u524D\u3002</p>
${models}
</section>
<section id="use-cases"><h2>UC \u306E\u4E00\u89A7</h2>
${useCaseIndex(view)}
</section>
${stray}
${view.useCases.map((uc) => sliceSection(uc, view)).join("\n")}
<script>
for (const b of document.querySelectorAll('button[data-defs]')) {
  b.addEventListener('click', () => {
    for (const d of document.querySelectorAll('div.defs')) d.hidden = b.dataset.defs !== 'open';
  });
}
for (const t of document.querySelectorAll('.term')) {
  t.addEventListener('click', () => {
    const d = t.closest('li')?.querySelector('div.defs');
    if (d) d.hidden = !d.hidden;
  });
}
</script>
<script type="module">
import mermaid from '${MERMAID_URL}';
const dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
mermaid.initialize({ startOnLoad: true, securityLevel: 'strict', theme: dark ? 'neutral' : 'default' });
</script>
</body>
</html>
`;
}

// src/view.ts
import { existsSync as existsSync4, readdirSync as readdirSync2, readFileSync as readFileSync4 } from "node:fs";
import { join as join4 } from "node:path";
function str(row, key) {
  const v = row.data[key];
  return typeof v === "string" ? v.trim() : "";
}
function list(row, key) {
  const v = row.data[key];
  if (typeof v === "string") {
    const parts = row.def.splitKeys.includes(key) ? v.split("\u3001") : [v];
    return parts.map((s) => s.trim()).filter((s) => s !== "");
  }
  if (Array.isArray(v)) return v.filter((x) => typeof x === "string" && x.trim() !== "").map((x) => x.trim());
  return [];
}
function hypothesisOf(row) {
  return Object.hasOwn(row.data, "\u4EEE\u8AAC") ? list(row, "\u4EEE\u8AAC") : null;
}
function listFiles2(root, dir, pattern) {
  const path = join4(root, dir);
  if (!existsSync4(path)) return [];
  return readdirSync2(path).filter((f) => pattern.test(f)).sort().map((f) => `${dir}/${f}`);
}
function scenarioView(s) {
  return { name: s.name, count: s.expansions.length };
}
function buildStateModels(rows, ucNames) {
  const models = /* @__PURE__ */ new Map();
  const statesOf = /* @__PURE__ */ new Map();
  for (const r of rows["state"]) {
    const st = str(r, "\u72B6\u614B");
    if (st === "") continue;
    if (!statesOf.has(r.name)) statesOf.set(r.name, /* @__PURE__ */ new Set());
    statesOf.get(r.name).add(st);
  }
  for (const r of rows["state"]) {
    let m = models.get(r.name);
    if (m === void 0) {
      m = { name: r.name, states: [], transitions: [] };
      models.set(r.name, m);
    }
    const from = str(r, "\u72B6\u614B") || null;
    const to = str(r, "\u9077\u79FB\u5148\u72B6\u614B") || null;
    const uc = str(r, "\u9077\u79FBUC") || null;
    for (const s of [from, to]) if (s !== null && !m.states.includes(s)) m.states.push(s);
    m.transitions.push({
      from,
      to,
      uc,
      ucKnown: uc === null || ucNames.has(uc),
      toKnown: to === null || (statesOf.get(r.name)?.has(to) ?? false),
      description: str(r, "\u72B6\u614B\u30E2\u30C7\u30EB\u30FB\u72B6\u614B\u306E\u8AAC\u660E"),
      hypothesis: Object.hasOwn(r.data, "\u4EEE\u8AAC")
    });
  }
  return [...models.values()];
}
function buildView(root) {
  const rows = loadTables(root, []);
  const byName = (id) => new Map(rows[id].map((r) => [r.name, r]));
  const actors = byName("actor");
  const externalSystems = byName("external-system");
  const information = byName("information");
  const conditions = byName("condition");
  const variations = byName("variation");
  const ucNames = new Set(rows["use-case"].map((r) => r.name));
  const modelNames = new Set(rows["state"].map((r) => r.name));
  const stateModels = buildStateModels(rows, ucNames);
  const namesOfKind = /* @__PURE__ */ new Map([
    ["\u30A2\u30AF\u30BF\u30FC", new Set(actors.keys())],
    ["\u5916\u90E8\u30B7\u30B9\u30C6\u30E0", new Set(externalSystems.keys())],
    ["\u60C5\u5831", new Set(information.keys())],
    ["\u72B6\u614B\u30E2\u30C7\u30EB", modelNames],
    ["UC", ucNames],
    ["\u6761\u4EF6", new Set(conditions.keys())],
    ["\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3", new Set(variations.keys())],
    ["\u30A2\u30FC\u30AD\u30C6\u30AF\u30C1\u30E3\u7279\u6027", new Set(rows["architecture-characteristic"].map((r) => r.name))]
  ]);
  const variationView = (name) => {
    const row = variations.get(name);
    return {
      name,
      known: row !== void 0,
      values: row ? list(row, "\u5024") : [],
      description: row ? str(row, "\u8AAC\u660E") : ""
    };
  };
  const definitionOf = (kind, name) => {
    if (name === null) return null;
    if (kind === "\u6761\u4EF6") {
      const row = conditions.get(name);
      if (row === void 0) return null;
      return {
        description: str(row, "\u6761\u4EF6\u306E\u8AAC\u660E"),
        values: [],
        attributes: [],
        variations: list(row, "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3").map(variationView)
      };
    }
    if (kind === "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3") {
      const v = variationView(name);
      return v.known ? { description: v.description, values: v.values, attributes: [], variations: [] } : null;
    }
    if (kind === "\u60C5\u5831") {
      const row = information.get(name);
      if (row === void 0) return null;
      return { description: str(row, "\u8AAC\u660E"), values: [], attributes: list(row, "\u5C5E\u6027"), variations: [] };
    }
    return null;
  };
  const referenceKnown = (kind, name) => {
    if (kind === null || name === null) return false;
    if (kind === "\u72B6\u614B") {
      const i = name.indexOf(REQUIREMENT_STATE_SEP);
      if (i < 0) return false;
      const model = stateModels.find((m) => m.name === name.slice(0, i).trim());
      return model?.states.includes(name.slice(i + REQUIREMENT_STATE_SEP.length).trim()) ?? false;
    }
    return namesOfKind.get(kind)?.has(name) ?? false;
  };
  const requirements = listFiles2(root, LAYOUT.requirements, /\.md$/).map((file) => ({
    file,
    req: parseRequirement(readFileSync4(join4(root, file), "utf8"))
  }));
  const features = [];
  const unreadableExamples = [];
  for (const file of listFiles2(root, LAYOUT.examples, /\.feature$/)) {
    const parsed = parseExample(readFileSync4(join4(root, file), "utf8"));
    if (!parsed.ok) {
      unreadableExamples.push({ file, message: parsed.message });
    } else if (parsed.feature === null) {
      unreadableExamples.push({ file, message: "\u6A5F\u80FD\uFF08Feature\uFF09\u304C\u7121\u3044" });
    } else {
      features.push({
        file,
        name: parsed.feature.name,
        rules: parsed.feature.rules.map((r) => ({ name: r.name, scenarios: r.scenarios.map(scenarioView) })),
        loose: parsed.feature.looseScenarios.map(scenarioView)
      });
    }
  }
  const useCases = rows["use-case"].map((r, i) => {
    const ownRequirements = requirements.filter((q) => q.req.ucName === r.name);
    const ownFeatures = features.filter((f) => f.name === r.name);
    const rules = ownFeatures.flatMap((f) => f.rules);
    const sentences = new Set(ownRequirements.flatMap((q) => q.req.lines.map((l) => l.text)));
    return {
      name: r.name,
      anchor: `uc-${i + 1}`,
      description: str(r, "\u8AAC\u660E"),
      hypothesis: hypothesisOf(r),
      actors: list(r, "\u30A2\u30AF\u30BF\u30FC").map((name) => ({
        name,
        known: actors.has(name),
        role: actors.has(name) ? str(actors.get(name), "\u5F79\u5272") : ""
      })),
      externalSystems: list(r, "\u5916\u90E8\u30B7\u30B9\u30C6\u30E0").map((name) => ({
        name,
        known: externalSystems.has(name),
        role: externalSystems.has(name) ? str(externalSystems.get(name), "\u5F79\u5272") : ""
      })),
      information: list(r, "\u60C5\u5831").map((name) => {
        const row = information.get(name);
        return {
          name,
          known: row !== void 0,
          description: row ? str(row, "\u8AAC\u660E") : "",
          attributes: row ? list(row, "\u5C5E\u6027") : []
        };
      }),
      conditions: list(r, "\u6761\u4EF6").map((name) => {
        const row = conditions.get(name);
        return {
          name,
          known: row !== void 0,
          description: row ? str(row, "\u6761\u4EF6\u306E\u8AAC\u660E") : "",
          variations: (row ? list(row, "\u30D0\u30EA\u30A8\u30FC\u30B7\u30E7\u30F3") : []).map(variationView)
        };
      }),
      stateModels: stateModels.filter((m) => m.transitions.some((t) => t.uc === r.name)).map((m) => m.name),
      requirements: ownRequirements.map(({ file, req }) => ({
        file,
        reason: req.reason,
        lines: req.lines.map((l) => ({
          ordinal: l.ordinal,
          text: l.text,
          reason: l.reason,
          references: parseReferences(l.rdra).map((ref) => ({
            raw: ref.raw,
            known: referenceKnown(ref.kind, ref.name),
            kind: ref.kind,
            name: ref.name,
            definition: definitionOf(ref.kind, ref.name)
          })),
          scenarios: rules.filter((rule) => rule.name === l.text).flatMap((rule) => rule.scenarios)
        }))
      })),
      exampleFiles: ownFeatures.map((f) => f.file),
      unlinkedRules: rules.filter((rule) => !sentences.has(rule.name)),
      looseScenarios: ownFeatures.flatMap((f) => f.loose)
    };
  });
  return {
    root,
    stateModels,
    useCases,
    strayRequirements: requirements.filter((q) => q.req.ucName === null || !ucNames.has(q.req.ucName)).map((q) => ({ file: q.file, ucName: q.req.ucName })),
    strayExamples: features.filter((f) => !ucNames.has(f.name)).map((f) => ({ file: f.file, name: f.name })),
    unreadableExamples,
    tableNames: [
      .../* @__PURE__ */ new Set([...Object.values(rows).flatMap((rs) => rs.map((r) => r.name)), ...stateModels.flatMap((m) => m.states)])
    ]
  };
}

// src/render.ts
function writeView(root, now = /* @__PURE__ */ new Date()) {
  const out = join5(root, LAYOUT.output);
  const html = renderHtml(buildView(root), now);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, html);
  return out;
}

// src/main.ts
var USAGE = "\u4F7F\u3044\u65B9: living-spec check [--doc-missing] [\u6839] | living-spec render [\u6839] | living-spec hook";
function usage() {
  console.error(USAGE);
  process.exit(2);
}
function die(message) {
  process.stderr.write(`${message}
`);
  process.exit(2);
}
function prepare(arg) {
  const root = resolve(arg ?? process.cwd());
  try {
    configureLayout(root);
  } catch (e) {
    die(`${CONFIG_FILE} \u3092\u8AAD\u3081\u306A\u3044: ${e.message}`);
  }
  const tables = join6(root, LAYOUT.tables);
  if (!existsSync5(tables)) die(`\u8868\u306E\u7F6E\u304D\u5834\u304C\u898B\u3064\u304B\u3089\u306A\u3044: ${tables}\uFF08\u6839\u3067\u5B9F\u884C\u3059\u308B\u304B\u3001\u6839\u3092\u5F15\u6570\u3067\u6E21\u3059\u3002\u7F6E\u304D\u5834\u306F ${CONFIG_FILE} \u306E tables\uFF09`);
  return root;
}
function runCheck(args2) {
  const docMissing = args2.includes("--doc-missing");
  const rest = args2.filter((a) => a !== "--doc-missing");
  if (rest.length > 1 || rest.some((a) => a.startsWith("--"))) usage();
  const root = prepare(rest[0]);
  const label = docMissing ? "\u8981\u6C42\u7968\u30FB\u4F8B\u306E\u66F8\u304D\u6F0F\u3089\u3057\u306E\u691C\u67FB" : "RDRA \u306E\u691C\u67FB";
  const violations = docMissing ? checkDocMissing(root) : checkRepo(root);
  if (violations.length === 0) {
    console.log(`${label}: \u9055\u53CD\u306A\u3057`);
    process.exit(0);
  }
  for (const v of violations) console.log(formatViolation(v));
  console.log(`${label}: \u9055\u53CD ${violations.length} \u4EF6`);
  process.exit(1);
}
function runRender(args2) {
  if (args2.length > 1 || args2.some((a) => a.startsWith("--"))) usage();
  console.log(writeView(prepare(args2[0])));
  process.exit(0);
}
function runHook() {
  let input;
  try {
    input = JSON.parse(readFileSync5(0, "utf8"));
  } catch (e) {
    die(`living-spec \u30D5\u30C3\u30AF: \u6A19\u6E96\u5165\u529B\u306E JSON \u3092\u8AAD\u3081\u306A\u3044\uFF08${e.message}\uFF09`);
  }
  const obj = typeof input === "object" && input !== null ? input : {};
  const filePath = obj.tool_input?.file_path;
  if (typeof filePath !== "string" || filePath === "") process.exit(0);
  const root = resolve(process.env.CLAUDE_PROJECT_DIR || (typeof obj.cwd === "string" ? obj.cwd : process.cwd()));
  const rel = relative(root, resolve(root, filePath)).split("\\").join("/");
  const configExists = existsSync5(join6(root, CONFIG_FILE));
  try {
    configureLayout(root);
  } catch (e) {
    die(`living-spec \u30D5\u30C3\u30AF: ${CONFIG_FILE} \u3092\u8AAD\u3081\u306A\u3044\uFF08${e.message}\uFF09`);
  }
  if (!LAYOUT.hook || !existsSync5(join6(root, LAYOUT.tables))) process.exit(0);
  const inScope = configExists && rel === CONFIG_FILE || [LAYOUT.tables, LAYOUT.requirements, LAYOUT.examples].some((d) => rel.startsWith(`${d}/`));
  if (!inScope) process.exit(0);
  let violations;
  try {
    violations = checkRepo(root);
  } catch (e) {
    die(`living-spec \u30D5\u30C3\u30AF: \u691C\u67FB\u5668\u3092\u5B9F\u884C\u3067\u304D\u306A\u3044\uFF08${e.message}\uFF09`);
  }
  try {
    writeView(root);
  } catch (e) {
    process.stderr.write(`living-spec \u30D5\u30C3\u30AF: \u8A2D\u8A08\u306E\u53EF\u8996\u5316\u3092\u63CF\u3051\u306A\u3044\uFF08${e.message}\uFF09
`);
  }
  if (violations.length === 0) process.exit(0);
  die(`RDRA \u306E\u691C\u67FB\u3067\u9055\u53CD\u304C ${violations.length} \u4EF6\u3042\u308B\uFF08${rel} \u306E\u7DE8\u96C6\u5F8C\uFF09\u3002\u76F4\u3059\u3053\u3068\u3002
${violations.map(formatViolation).join("\n")}`);
}
var [command, ...args] = process.argv.slice(2);
if (command === "check") runCheck(args);
if (command === "render") runRender(args);
if (command === "hook" && args.length === 0) runHook();
usage();
