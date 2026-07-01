/**
 * Compatibility shim for auth0-evals.
 *
 * Reads graders.json (rich format with custom types, tier, description)
 * and exports defineGraders() returning auth0-evals GraderDef[] format.
 *
 * Custom type mappings:
 *   file_contains  → contains (loses file-specificity)
 *   contains_any   → contains (first value only)
 *   not_contains_any → not_contains (first value only)
 *   all            → flattened sub-graders
 *   judge.examples → stripped
 */
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

/** auth0-evals GraderDef — the format runGraders() expects */
export interface GraderDef {
  kind: string;
  name: string;
  needle?: string;
  pattern?: string;
  question?: string;
  framework?: string;
}

/** Rich grader from graders.json (superset of auth0-evals types) */
interface RichGrader {
  type: string;
  value?: string;
  values?: string[];
  pattern?: string;
  description?: string;
  question?: string;
  examples?: string;
  framework?: string;
  file_pattern?: string;
  tier?: number;
  graders?: RichGrader[];
}

function mapGrader(g: RichGrader): GraderDef | GraderDef[] {
  const name = g.description ?? "";

  switch (g.type) {
    case "contains":
      return { kind: "contains", needle: g.value, name };

    case "file_contains":
      return { kind: "contains", needle: g.value, name };

    case "contains_any":
      return { kind: "contains", needle: g.values?.[0], name };

    case "not_contains":
      return { kind: "not_contains", needle: g.value, name };

    case "not_contains_any":
      return { kind: "not_contains", needle: g.values?.[0], name };

    case "matches":
      return { kind: "matches", pattern: g.pattern, name };

    case "all":
      return (g.graders ?? []).flatMap((sub) => {
        const mapped = mapGrader(sub);
        return Array.isArray(mapped) ? mapped : [mapped];
      });

    case "judge":
      return {
        kind: "judge",
        question: g.question,
        framework: g.framework,
        name: g.question?.slice(0, 80) ?? name,
      };

    default:
      return { kind: g.type, name };
  }
}

/**
 * Reads graders.json and returns auth0-evals compatible GraderDef[].
 * Custom types are mapped to standard primitives (contains, not_contains, matches, judge).
 */
export function defineGraders(): GraderDef[] {
  const raw: RichGrader[] = JSON.parse(
    readFileSync(join(__dirname, "graders.json"), "utf-8")
  );
  return raw.flatMap((g) => {
    const mapped = mapGrader(g);
    return Array.isArray(mapped) ? mapped : [mapped];
  });
}
