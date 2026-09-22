# The Build Guide

One way to build the platformer, milestone by milestone. Every milestone ends
with something you can run. Commit and push at each one.

Ground rules, same as always:

- **This is a guide, not a script.** Boxes marked *Dials* hold values meant to
  be tuned; boxes marked *Your call* mark places where the design is up to
  you. Deviate freely as long as the README requirements are met.
- **Ask "which class moment is this?"** The body is Lab 2's paddle turned
  sideways plus gravity. The layers are week 2. The spike and flag are the
  marionberry's `Area2D` trick. The state machine is Tuesday's lecture,
  running on your keyboard.

The plan: a Bearcat with a brain made of rooms. One state at a time, each
state owning its own rules.

---

## Milestone 0: Open the level

1. Clone your repo and open `project.godot` in Godot.
2. Run the project. A floor, two walls, and four platforms climbing to the
   right is correct. Stop it.

---

## Milestone 1: A body with gravity

**Actions and layers first.** Two trips into Project Settings:

1. **Project → Project Settings → Input Map** tab. Add an action named
   **`move_left`**, then use its **+** button to bind the **Left Arrow**, and
   again to bind **A**. Add **`move_right`** (Right Arrow, D) and **`jump`**
   (Space, and W if you like). Close the dialog.
2. **Project → Project Settings → General**, search **"layer names"**, open
   **Layer Names → 2D Physics**. Name layer 1 **`world`**, layer 2
   **`player`**, layer 3 **`hazards`**, layer 4 **`goal`**.
3. Both live in `project.godot`. Commit that file.

**The scene.**

1. **Scene → New Scene**, root: **Other Node → `CharacterBody2D`**, renamed
   **`Player`**.
2. Add a **`Sprite2D`** child and drag **`assets/player-idle.png`** onto its
   **Texture** slot.
3. Select `Player` again and add a **`CollisionShape2D`** child. In the
   Inspector choose **Shape → New RectangleShape2D** and size it to cover the
   sprite (about 32 x 48).
4. Still on the `Player` root, find **Collision** in the Inspector. Set
   **Layer** to `player` only (box 2) and **Mask** to `world` only (box 1).
   In English: "I am the player; the level stops me."
5. Save as **`player.tscn`**.

**The script.** Right-click `Player`, choose **Attach Script**, keep
`res://player.gd`, and make it:

```gdscript
extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 1400.0

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta

    var direction := Input.get_axis("move_left", "move_right")
    velocity.x = direction * speed

    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity

    move_and_slide()
```

Three things worth reading twice:

- **Gravity is just velocity math.** Every physics tick that you are not on
  the floor, `velocity.y` grows by `gravity * delta`. The engine does not
  pull you down; your own script does, on the physics clock.
- **`is_on_floor()` is free.** `move_and_slide` computes it every frame from
  real collisions with the `world` layer. No raycasts, no flags you maintain.
- **`jump_velocity` is negative** because y grows downward in 2D. Up is less.

**Put it in the world.** Open **`main.tscn`**, select the `Main` root,
instance **`player.tscn`** into it (the chain-link icon), and set its
position to about `(100, 550)` (on the floor, left side). Save and run. Run,
jump, climb the platforms.

> **Dials:** `speed`, `jump_velocity`, `gravity`. These three numbers are
> most of what makes a platformer feel floaty or heavy. Spend five minutes
> here; it is the cheapest game feel you will ever buy.
>
> **Your call:** taller jumps with lower gravity? Snappy arcs with both
> cranked up? There is no correct answer, only your answer.

**Commit:** `git add -A`, commit, push.

---

## Milestone 2: The brain transplant

The M1 script works, and it is already starting to rot. Where would double
jump go? A dash? A wall slide? Every answer is "another `if`, guarded by
flags, tested against every other flag." Tuesday's lecture named the way out:
**give the player exactly one state at a time, and give each state its own
rules.**

Rewrite **`player.gd`** (replace the whole file):

```gdscript
extends CharacterBody2D

enum State { IDLE, RUN, AIR }

@export var speed: float = 300.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 1400.0

var state: State = State.IDLE

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta

    var direction := Input.get_axis("move_left", "move_right")
    velocity.x = direction * speed

    match state:
        State.IDLE:
            if Input.is_action_just_pressed("jump"):
                velocity.y = jump_velocity
            if not is_on_floor():
                _change_state(State.AIR)
            elif direction != 0.0:
                _change_state(State.RUN)
        State.RUN:
            if Input.is_action_just_pressed("jump"):
                velocity.y = jump_velocity
            if not is_on_floor():
                _change_state(State.AIR)
            elif direction == 0.0:
                _change_state(State.IDLE)
        State.AIR:
            if is_on_floor():
                _change_state(State.IDLE if direction == 0.0 else State.RUN)

    move_and_slide()

func _change_state(new_state: State) -> void:
    state = new_state
    print("state: ", State.keys()[new_state])
```

Run it. **The game plays exactly the same.** That is the point: a refactor
changes the shape of the code, not the behavior. Watch the Output panel
narrate your movement instead.

Read the shape:

- **The enum names the rooms.** `State.IDLE`, `State.RUN`, `State.AIR`. The
  player is always in exactly one.
- **The `match` gives each room its own rules.** Notice `AIR` has no jump
  line: that is why you cannot jump mid-air. Not because a flag forbids it,
  but because *that room has no jump in it*.
- **`_change_state` is the only door.** Every transition goes through one
  function. When states later need entry effects (a sprite, a sound, a
  squash), there is exactly one place to put them.

> **Your call:** some builders split IDLE and RUN later, or merge them. Keep
> at least three states, and keep the door rule: all changes through
> `_change_state`.

**Commit.**

---

## Milestone 3: States you can see

Three poses shipped in `assets/`. Wire them to the states so the machine is
visible on screen, not just in the Output panel. In **`player.gd`**:

1. Add the texture table near the top (under the `@export` lines):

```gdscript
const TEXTURES := {
    State.IDLE: preload("res://assets/player-idle.png"),
    State.RUN: preload("res://assets/player-run.png"),
    State.AIR: preload("res://assets/player-jump.png"),
}
```

2. Grow **`_change_state`** into a real doorway (replace the function):

```gdscript
func _change_state(new_state: State) -> void:
    state = new_state
    $Sprite2D.texture = TEXTURES[new_state]
```

3. Face where you run. Add two lines in `_physics_process`, right after the
   `velocity.x = direction * speed` line:

```gdscript
    if direction != 0.0:
        $Sprite2D.flip_h = direction < 0
```

Run it. Idle Bearcat, running Bearcat, airborne Bearcat, and the sprite work
lives **in the door function**, not scattered through the `match`. That is
the entry-effect pattern: when you enter a room, the room dresses you.

> **Your call:** `modulate` tints per state instead of (or on top of)
> textures; a landing squash (`scale` briefly) when AIR exits to a floor
> state. All of it goes in `_change_state`.

**Commit.**

---

## Milestone 4: The world pushes back

**The spike.** New scene, root **Other Node → `Area2D`**, renamed
**`Spike`** (it senses; it never blocks). Add a `Sprite2D` with
**`assets/spike.png`** and a `CollisionShape2D` (**New RectangleShape2D**,
about 32 x 20, nudged to the triangles). On the root set **Collision →
Layer** to `hazards` (box 3) and **Mask** to `player` (box 2). Save as
**`spike.tscn`**.

**Connect the signal.** With the `Spike` root selected, open the **Node**
dock (next to Inspector), double-click **`body_entered`**, and connect it to
the script it offers to create (`res://spike.gd`). Make the function:

```gdscript
extends Area2D

func _on_body_entered(body: Node2D) -> void:
    if body.has_method("respawn"):
        body.respawn()
```

`has_method` again: the spike does not ask "are you the player?", it asks
"can you respawn?". Anything that answers gets sent home.

**Teach the player to respawn.** In **`player.gd`**, add a spawn memory and
the method the spike is calling:

```gdscript
var spawn_point: Vector2

func _ready() -> void:
    spawn_point = position
```

```gdscript
func respawn() -> void:
    position = spawn_point
    velocity = Vector2.ZERO
    _change_state(State.AIR)
```

And make the void below the map lethal too. At the bottom of
`_physics_process`, after `move_and_slide()`:

```gdscript
    if position.y > get_viewport_rect().size.y + 100.0:
        respawn()
```

**The flag.** New scene, root **`Area2D`** named **`Flag`**, sprite
**`assets/flag.png`**, a `CollisionShape2D` covering it, **Layer** `goal`
(box 4), **Mask** `player` (box 2). Connect `body_entered` the same way
(`res://flag.gd`):

```gdscript
extends Area2D

func _on_body_entered(body: Node2D) -> void:
    print("CLEAR!")
```

**Dress the level.** In `main.tscn`, instance a `spike.tscn` or two on the
floor (around `(650, 588)` sits nicely on it) and the `flag.tscn` on the top
platform (about `(1000, 170)`). Save, run, die, respawn, climb, plant it.

> **Dials:** spike placement is level design. One cruel spike beats five
> boring ones.
>
> **Your call:** a "CLEAR!" that actually ends the level (reload the scene,
> freeze the player in a new WIN state, load a second level). The print is
> the floor, not the ceiling.

**Commit.**

---

## Milestone 5: Make it yours (required)

Pick **at least one**, or invent your own of similar size. Name it in the
README's **Your Submission** section. The best ones are *new states* or *new
rules for existing states*, because that is the muscle this lab trains.

- **Double jump.** One extra jump while in AIR. A counter that resets on
  landing, or a second air state if you want the sprite to show it.
- **Coyote time.** For a few frames after running off a ledge, jump still
  works. Small timer, huge feel. (Ask the internet why it is named this.)
- **Dash.** A DASH state: a burst of speed, a short timer, then back. Entry
  effect, exit rule, its own room. This is the pattern at full strength.
- **Wall jump.** `is_on_wall()` is free, like `is_on_floor()`. A WALL state
  that slides slowly and jumps away.
- **Collectible berries.** Marionberries on the platforms, an `Area2D`, a
  signal, a score. You have built every piece of this before.
- **Moving platform.** An `AnimatableBody2D` sliding back and forth carries
  the player for free. Sync its motion to the physics clock.
- **A second level.** The flag loads `level2.tscn`. Scene composition pays
  off.
- **Reskin it.** New sprites, new palette, new fiction. The states do not
  care what they wear.

---

## Nothing happened?

| Symptom | Cause and cure |
| --- | --- |
| Player falls through the floor | The player's **Mask** is missing box 1, or `level.tscn` was removed from `Main`. Whose layer, whose mask? |
| Jump does nothing | `is_on_floor()` is false: you are checking it before `move_and_slide()` has ever run with floor contact, or the action name in the code does not match the Input Map exactly. |
| Infinite jumps in midair | The jump line lives outside the `match` (or in the AIR branch). The room with no jump in it is the fix, not a flag. |
| Sprite never changes | Transitions are bypassing `_change_state` (a bare `state = ...` somewhere), or the TEXTURES dictionary paths do not match the files. |
| Stuck in one state forever | A transition condition can never fire. Print `State.keys()[state]` every frame and watch which room you are trapped in. |
| Spikes are decorative | The spike's **Mask** is missing `player`, or you connected `area_entered` instead of **`body_entered`** (the player is a body). |
| "Action already exists" | You are re-adding actions that are already in `project.godot`. Check the Input Map before typing. |
| Editor shows stale actions or layers after a checkout | Project Settings do not reload from disk. Run **Project → Reload Current Project** without saving first. |

The checklist, week 5 edition: which scene ran, is the node in it, is the
script saved, whose layer, whose mask, **which state are you in?**
