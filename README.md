# Does This Work?

An offline industrial engineering puzzle game. Assign a crew to stations, find a production bottleneck, lay out a factory, and plan a delivery route. The game supports English and Thai.

เกมพัซเซิลวิศวกรรมอุตสาหการแบบออฟไลน์ จัดคนลงสถานี หาคอขวด วางผังโรงงาน และจัดเส้นทางส่งของ เลือกภาษาไทยหรืออังกฤษได้ใน **Settings → Language**

![Four puzzle boards in Thai showing staffing, production bottlenecks, plant layout, and delivery routes](docs/images/four-stages-th.png)

## Play

Download **v0.6 Beta** from [GitHub Releases](../../releases), then extract the archive for your computer.

| Platform | Open after extracting |
| --- | --- |
| macOS 14 or later on Apple Silicon | `Does This Work?.app` |
| Windows 64-bit on Intel/AMD | `Does This Work.exe` inside the extracted folder |

The beta includes 360 puzzles across four stages. Each run draws six puzzles. Complete a run to unlock the next stage. The Windows build has been checked against all 360 reference solutions, and the macOS app signature has been verified. Desktop launch and playthrough testing of the packaged beta is still pending.

## Screenshots

**Before the shift.** The crew talks through the problem before the puzzle starts.

![Two geometric workers in a factory with a Thai dialogue bubble above the speaker](docs/images/crew-dialogue-th.png)

**Checking the plan.** The checkmark turns green once every condition is met.

![Thai confirmation panel comparing a gray checkmark for an incomplete plan with a green checkmark for a valid plan](docs/images/confirm-plan-states-th.png)

## Build from source

- **macOS.** With Xcode selected, run `cd macOS && bash Scripts/build.sh`. The app appears under `macOS/outputs/`. [macOS build and test instructions](macOS/README.md)
- **Windows.** With Node.js and Python 3.11 or later, run `cd Windows && node qa/test.mjs` for the puzzle checks. The packaging script uses a verified copy of the Electron Windows x64 runtime. [Windows build instructions](Windows/README.md)

Game rules, puzzle data, dialogue, fonts, and gameplay audio are included. See the platform READMEs for build tools and validation commands.

## Licenses and credits

- Game code and build scripts are available under the [MIT License](LICENSE).
- Original artwork, music, sound effects, dialogue, and puzzle designs use [CC BY 4.0](ASSETS-LICENSE.md). Credit Sua and the Does This Work? contributors when reusing these assets.
- Mali and Sarabun are bundled under the SIL Open Font License 1.1. [Mali license](macOS/Resources/Fonts/OFL-Mali.txt) · [Sarabun license](macOS/Resources/Fonts/OFL-Sarabun.txt)
- The Windows distribution includes Electron and its third-party license notices. See the [Windows asset credits](Windows/app/ASSETS-LICENSE.md) for paths and font credits.

## Feedback

For bugs or puzzle feedback, open an [issue](../../issues) with the game version, operating system, and puzzle title. For a pull request, include the tests you ran.
