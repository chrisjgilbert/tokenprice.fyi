---
name: code-smells
description: Review Ruby/Rails code for code smells using thoughtbot's Ruby Science catalog (https://github.com/thoughtbot/ruby-science). Use when asked to check for code smells, review Ruby code quality, find refactoring opportunities, or audit a class/method/diff against Ruby Science. Detects smells like Long Method, Large Class, Feature Envy, Case Statement, Shotgun Surgery, Divergent Change, Long Parameter List, Duplicated Code, Uncommunicative Name, STI, Comments, Mixin, and nil-checks, and names the matching refactoring for each.
---

# Code Smells (Ruby Science)

Detect code smells from thoughtbot's *Ruby Science* and recommend the matching
refactoring. Source: https://github.com/thoughtbot/ruby-science

## How to run a review

1. **Scope the target.** Default to the current diff:
   `git diff main...HEAD` (fall back to `git diff HEAD`). If the user names a
   file, class, or method, review that instead. For a whole-app sweep, prefer
   `app/models`, `app/services`, `app/controllers`, and `app/jobs`.
2. **Run the linters first** — they catch the mechanical smells for free:
   - `bin/rubocop` (this repo uses `rubocop-rails-omakase`)
   - If `reek` is available (`bundle exec reek <path>`), use it; it maps almost
     1:1 to this catalog. It is not a dependency here, so don't assume it.
3. **Read each method/class against the catalog below.** For every finding,
   report: the smell, the `file:line`, *why* it qualifies (cite the heuristic),
   and the specific refactoring to apply. One smell can suggest several
   refactorings — name the best fit first.
4. **Rank by payoff, not count.** Lead with smells that make the code hard to
   change (Divergent Change, Shotgun Surgery, Large Class) over cosmetic ones.
   A smell is a *prompt to look*, not a guaranteed defect — say so when a smell
   is justified in context.

## Output format

Group findings by file. For each:

```
app/services/foo.rb:42 — Long Method (`#call`, 38 lines, 3 levels of nesting)
  Why: does fetching, parsing, and persistence in one method.
  Refactor: Extract Method for each phase; consider Extract Class if the
  parsing logic has its own state.
```

End with a short summary: top 3 things worth fixing, and what's fine as-is.

## The catalog: smell → detection → refactoring

### Long Method
- **Detect:** more than ~10 lines; multiple levels of abstraction in one body;
  comments separating "sections"; deep nesting.
- **Refactor:** Extract Method; Replace Temp with Query; Introduce Explaining
  Variable; Replace Conditional with Polymorphism/Null Object.

### Large Class / God Class
- **Detect:** many instance variables; low cohesion (methods touch disjoint
  subsets of state); the class name is vague (`Manager`, `Helper`, `Service`)
  and keeps growing. Watch fat models and fat controllers especially.
- **Refactor:** Extract Class; Extract Value Object; Extract Decorator; Move
  Method; Replace Subclasses with Strategies; Introduce Form/Parameter Object.

### Feature Envy
- **Detect:** a method calls another object's accessors repeatedly
  (`other.x`, `other.y`, `other.z`) and uses `self` little; logic that belongs
  on the data it operates on. Law of Demeter violations (`a.b.c.d`) are a tell.
- **Refactor:** Move Method onto the envied class; Extract Method then move it;
  Inline Class; add a delegating method (Demeter).

### Case Statement / Type Codes / Conditional Complexity
- **Detect:** `case` on a `type`/`kind`/`status` string or symbol; the same
  `case`/`if` branching on the same condition in more than one place; checking
  `is_a?`/`respond_to?`/`class ==`.
- **Refactor:** Replace Conditional with Polymorphism; Replace Conditional with
  Null Object; Replace Type Code with Subclasses/Strategies; Extract Method to
  name the condition.

### Shotgun Surgery
- **Detect:** one conceptual change forces edits across many files/classes
  (e.g. adding an enum value means touching a model, a view, a serializer, and
  a job). Repeated literals/magic values scattered around.
- **Refactor:** Inline Class / Move Method to consolidate; introduce a single
  object that owns the concept (Value Object, Convention over Configuration).

### Divergent Change
- **Detect:** one class changes for many unrelated reasons (a model edited for
  validation, for formatting, and for API calls). The inverse of Shotgun
  Surgery.
- **Refactor:** Extract Class along the axes of change (e.g. Form Object for
  validation, Decorator/Presenter for formatting, a client object for I/O).

### Long Parameter List
- **Detect:** 3+ positional params; booleans-as-flags; params that always
  travel together.
- **Refactor:** Introduce Parameter Object; Introduce Form Object; Extract
  Class; use keyword args; replace flag args with separate methods.

### Duplicated Code
- **Detect:** copy-pasted blocks; parallel conditionals; structurally identical
  methods differing only in a value.
- **Refactor:** Extract Method/Class; Extract Partial (views); Replace
  Conditional with Polymorphism; pull up into a shared object (favor
  composition over a Mixin — see below).

### Uncommunicative Name
- **Detect:** single-letter or numbered names (`x`, `data2`, `tmp`); names that
  restate the type (`user_object`); abbreviations; method names that lie about
  what they do.
- **Refactor:** Rename; Introduce Explaining Variable; Extract Method to name a
  block of logic.

### Single Table Inheritance (STI)
- **Detect:** a `type` column with subclasses; subclasses that don't share most
  columns; conditionals on `type`.
- **Refactor:** Replace Subclasses with Strategies; use composition / separate
  tables. Ruby Science is skeptical of STI — flag it, don't auto-condemn.

### Comments
- **Detect:** comments explaining *what* code does (vs *why*); commented-out
  code; a comment that could be a method name.
- **Refactor:** Extract Method with an intention-revealing name; Introduce
  Explaining Variable; delete dead comments. Keep *why* comments.

### Mixin (overused modules)
- **Detect:** modules used to share code rather than model a real "is-a";
  mixins that reach into the host's private state; `concerns/` used as a junk
  drawer.
- **Refactor:** Replace Mixin with Composition; Extract Class; inject a
  collaborator instead of mixing in.

### Nil checks / repeated `&.` / `try`
- **Detect:** scattered `if x.nil?`, `x&.y`, `x.present?` guarding the same
  absent value in many places.
- **Refactor:** Replace Conditional/Nil-check with Null Object; push the default
  to where the value originates.

## Refactoring reference (when to reach for each)

- **Extract Method** — a method does more than one thing / has sections.
- **Extract Class** — a class has more than one responsibility (Divergent Change).
- **Extract Value Object** — a primitive (string/number) has behavior + validation
  (money, a price, a percentage). This repo has price/cost concepts — good targets.
- **Extract Decorator / Presenter** — view-specific formatting bloating a model.
- **Extract Partial / Validator / Form Object** — Rails-specific extractions.
- **Replace Conditional with Polymorphism** — branching on a type code.
- **Replace Conditional with Null Object** — branching on presence/nil.
- **Replace Subclasses with Strategies / Replace Mixin with Composition** —
  prefer composition over inheritance/mixins.
- **Introduce Explaining Variable / Parameter Object** — tame complex
  expressions and signatures.
- **Inject Dependencies** — hard-coded collaborators (e.g. `Net::HTTP`, a client)
  make a class hard to test; pass them in. See `AnthropicClient.build` for the
  repo's preferred construction pattern.

## Repo-specific notes

- Ruby 3.3.6, Rails. Style baseline is `rubocop-rails-omakase` — don't flag
  what RuboCop already governs as a "smell"; defer to it for formatting.
- Service objects live in `app/services` and are the most likely home for Long
  Method / Large Class / Feature Envy. Models in `app/models` for STI, Divergent
  Change, and fat-model smells.
- Don't propose a refactor that breaks the public interface without saying so.
  After suggesting changes, note that `bin/rails test` is the verification step.
