# LICENSING_DECISIONS

**Status:** owner decision required. No project license is selected or granted by this document. No third-party dependency or asset has been imported in this architecture task.

## Source-code choices

| Option | Principal effect | Owner question |
| --- | --- | --- |
| MIT | Short permissive terms; commercial reuse/modification/distribution allowed with required notices; no express patent grant in its text | Is maximum reuse, including closed commercial forks, acceptable? |
| Apache-2.0 | Permissive reuse with an express patent grant/termination provisions and notice/change obligations; no trademark license | Is the extra patent/notice structure worth more detailed terms? |
| MPL-2.0 | File-level copyleft; distributed modifications to covered files remain available under MPL, while larger works can include other terms subject to its conditions | Should improvements to existing covered files stay open without requiring all separate code to use the same license? |
| GPL-3.0 | Strong copyleft for conveyed covered/combined works, with corresponding-source obligations under its terms; commercial distribution is allowed | Should distributed derived/combined software remain under compatible copyleft terms? |
| Dual licensing | An open license plus separate commercial terms may be offered if the owner has the necessary rights | Is the administrative/contributor-rights burden justified by an actual business need? |

These are abbreviated decision descriptions; selection requires checking the full terms and the actual dependency/asset combinations. Primary texts: [MIT](https://opensource.org/license/mit), [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0), [Mozilla MPL FAQ](https://www.mozilla.org/en-US/MPL/2.0/FAQ/), [GPL-3.0](https://opensource.org/license/gpl-3.0).

Do not select a license by popularity or assume that “free to download” grants redistribution. Open-source licensing permits commercial use; prohibiting commercial activity or a field of use such as gambling is inconsistent with the Open Source Definition. Keep the product's no-real-money policy in its specification; do not silently add a use restriction to MIT/GPL and continue describing that license as open source. [Open Source Definition](https://opensource.org/osd).

Paid official builds can coexist with open-source code, but recipients may have redistribution rights under the applicable licenses. Do not promise exclusivity over reusable licensed source/binaries. A game's new commercial license cannot remove third-party obligations.

## Decide each category separately

| Category | Choices to resolve before public distribution |
| --- | --- |
| Original source | One approved source license and license headers/SPDX policy; whether dual licensing is actually needed |
| Original artwork/audio | Permissive art license (e.g. CC BY/CC0 as appropriate), share-alike terms, or expressly reserved rights; credit and modification permissions |
| Documentation | Specify documentation license separately or explicitly include it under the chosen source license |
| Royal Pocket Casino marks/logo | Define permitted attribution, unofficial fork naming, official-build identification, and use of logos; do not claim registered trademark status without evidence |
| MarkXimize Interactive marks/logo | Separate studio-brand permission policy; no implication that a code license grants endorsement |
| Official builds | Specify who signs/publishes official packages, required component notices/source availability, permissible redistribution, and how unofficial builds are identified |
| Contributions | Inbound rights under the chosen outbound license; DCO/sign-off or an appropriate CLA if necessary; rules for contributed assets/provenance |

Creative Commons recommends software-specific licenses for code, while its licenses can suit separate art/music/docs; logos/trademarks need a separate policy. [Creative Commons FAQ](https://creativecommons.org/faq/).

If assets are reserved, state plainly that source is open but those assets are restricted. Provide redistributable placeholder/replacement assets or a documented source-build route so community developers can build and test legally. Do not call a fully unrestricted asset package open when it is not.

Recommendation for process, not license selection: choose source terms first, use a clear per-category licensing map, and start with simple contribution terms. A CLA/rights assignment only belongs here if the owner's licensing model needs it; do not add one merely because commercial licensing is conceivable.

## Third-party rights and notices

Create `THIRD_PARTY_NOTICES.md` at the first import. Record **every** dependency/runtime component, font, sound, texture, icon, asset pack, strategy dataset and build-distributed resource. Include indirect/bundled native libraries, not only the game's direct Lua dependencies.

Each record needs name, exact version/hash, source URL/creator, license identifier and retained license text, included files, modifications, required attribution/notice placement, redistribution and commercial-use permissions, source-offer/availability obligations where applicable, and the targets whose packages include it.

Never import unattributed Internet images/sounds or assume an AI-generated asset automatically has clear rights. Keep creation provenance and applicable service/output terms. Review font embedding/redistribution and modifications separately. Check runtime packages themselves; a permissive game-code license does not license their contents.

Before each release, reconcile notices against the actual archive/APK/Web payload, include required notices/source information, and verify compatibility with the selected project terms. If rights are unclear, exclude the resource until resolved.

## OD-06 approval checklist

The owner must select source, original assets, documentation, both brands' usage policies, official-build distribution terms and inbound contribution policy. Record the final scope/license text in the relevant repository locations before public release. **This task deliberately creates no LICENSE file.**
