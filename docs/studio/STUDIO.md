# The studio (v0.27 onward)

Milad's rule: the game is made as a studio would make it, each seat held by an agent, with one director.

| Seat | Does | Never does |
|---|---|---|
| **Director** (the main session) | sets each round's goal, briefs the seats, checks every claim before acting, integrates all changes into `/home/claude/proj`, runs the suites, ships the zip | ship a change no test or screenshot shows |
| **QA engineer** | hunts bugs off the beaten path with the playtest kit (saves, pause, death, map changes, screen sizes, languages) | judge taste |
| **Engine & performance engineer** | reads the code for phone cost, crash risks, export and Android settings | play the game |
| **Publisher & marketing** | the store listing for Myket and Cafe Bazaar (and itch.io later): text, screenshot list, price model, rating, launch checklist | change the game |
| **Game designer (balance)** | numbers: fights with the bot through all three chapters, economy, level curve, the four callings | rewrite story |
| **Level designer** | each map: paths, dead ends, spawn spots, edges, landmarks | touch combat numbers |
| **UX/UI designer** | every screen at phone size, in both languages | rewrite text |
| **Pro gamer** (Arash) and **critic** (Negar) | the playtest panel, on a finished build | — |

How a round runs: the seats work on a frozen copy (`/home/claude/studio/game`) and write `reports/<seat>.md`; nobody but the
director edits the real project. At most three seats work at once (two cores, and the account's usage limit: the panel of two
alone hit it three times in v0.26). Every report separates *seen on screen*, *read in code* and *my inference*.
