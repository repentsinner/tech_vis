# [0.4.0](https://github.com/repentsinner/tech_vis/compare/v0.3.0...v0.4.0) (2026-11-16)


### Bug Fixes

* **dart:** keep an invisible edge label out of the ground grid's label set ([626a8fd](https://github.com/repentsinner/tech_vis/commit/626a8fdaca87aac6d4f11eb9ceb9136a1d6cd1d1))
* **dart:** keep step lengths exact past 64-bit integers ([9d68366](https://github.com/repentsinner/tech_vis/commit/9d6836652d38294c2005822a135634ed3460690f))
* **dart:** order tied navigation cube faces by a transitive rule ([3cab331](https://github.com/repentsinner/tech_vis/commit/3cab331813dbbcc7edde8d487efe69b5d433575c))


### Features

* **dart:** add an adaptive ground grid with minor and major lines ([c0f6d04](https://github.com/repentsinner/tech_vis/commit/c0f6d0490a0d67e2fc5ac5e4d025e0da0b49888e))
* **dart:** add angular dimensions drawn as an arc ([3b14c2c](https://github.com/repentsinner/tech_vis/commit/3b14c2c1e7a3c44688245c6d3dcc7eed62e5c7bb))
* **dart:** add point-to-point smart dimensions under a drafting convention ([b18da4b](https://github.com/repentsinner/tech_vis/commit/b18da4bca07f9a561df69c78be3a9cf64125c750))
* **dart:** add radial dimensions of a circle or arc ([0d4350c](https://github.com/repentsinner/tech_vis/commit/0d4350c5222bf6d530fb6486a00afef69a64908d))
* **dart:** answer composed text with app-sized billboard content ([7c28ee2](https://github.com/repentsinner/tech_vis/commit/7c28ee2fc73ec930f616058307047979e48f2051))
* **dart:** declare the coordinate convention ([0777378](https://github.com/repentsinner/tech_vis/commit/07773787d469b0db2baf5cac6ba0ff99f0e491d1))
* **dart:** describe a navigation cube overlay in viewport pixels ([7bb3565](https://github.com/repentsinner/tech_vis/commit/7bb35654d0f2cb647587d2b350d1f7bd8dd5a093))
* **dart:** emit a callout's leader as two lines ([da69426](https://github.com/repentsinner/tech_vis/commit/da6942639a1b18602853a703ea852edfdd40ddce))
* **dart:** emit typed primitives from the factories ([5eee5f9](https://github.com/repentsinner/tech_vis/commit/5eee5f9599c0161ba5d18e18b83eb10b04394498))
* **dart:** format measurements in metric, decimal-inch, and fractional-inch formats ([19f891d](https://github.com/repentsinner/tech_vis/commit/19f891dabf9124df9e7db9bee03eca3a8ce9b369))
* **dart:** generate marker spheres and their per-frame transform ([0e33ad3](https://github.com/repentsinner/tech_vis/commit/0e33ad3580e45592b27da3c342062a04418b8ccb))
* **dart:** lay out a scale bar in viewport pixels at the camera target ([64377a4](https://github.com/repentsinner/tech_vis/commit/64377a4356ba1e915e0a7dd60e6c45efba61f9ca))
* **dart:** lay out the color ramp legend ([aa33393](https://github.com/repentsinner/tech_vis/commit/aa33393ac43b1a2ec8d0dd3044f913f0d4575802))
* **dart:** orient envelope labels by the declared convention ([dfab981](https://github.com/repentsinner/tech_vis/commit/dfab981325ddf4c4f9210b116ae63fadf9ebf8e3))
* **dart:** place viewport overlays by corner, offset, and size ([bd92bc0](https://github.com/repentsinner/tech_vis/commit/bd92bc083df55abd3f9537797a6138d5263f0b4a))
* **dart:** project a world point to viewport pixels ([4ee7dd1](https://github.com/repentsinner/tech_vis/commit/4ee7dd193a97bfb37c00c905bb8d1fce74316216))
* **dart:** return a callout's label as a sized billboard ([8fb123b](https://github.com/repentsinner/tech_vis/commit/8fb123bb680c306f77ba4cf98a95ddc2b6ff6b29))
* **dart:** write angle labels in decimal degrees ([5632541](https://github.com/repentsinner/tech_vis/commit/5632541772b8230d14c70e0f045fc449450c6db0))
* **python:** emit callout leaders and labels as primitives ([46bfa96](https://github.com/repentsinner/tech_vis/commit/46bfa96bacadf626d0f0ab436988c91d19fec5d6))
* **python:** port smart dimensions ([efa9702](https://github.com/repentsinner/tech_vis/commit/efa9702f9b4cf20fb83569e0bd5997382575fbcb))
* **python:** port the adaptive ground grid ([748dc45](https://github.com/repentsinner/tech_vis/commit/748dc45a978fbf586c757d8826a5196db485e8c2))
* **python:** port the color ramp legend ([3d40741](https://github.com/repentsinner/tech_vis/commit/3d407416dd8ca00eb07bb3d386190e88d6c4b2d4))
* **python:** port the coordinate convention and camera basis ([89a8a10](https://github.com/repentsinner/tech_vis/commit/89a8a105972414b5e338492ae0685f9911d96b06))
* **python:** port the decimal-degree label ([5004e60](https://github.com/repentsinner/tech_vis/commit/5004e603e069d8ed5d406761bc387facdfeea417))
* **python:** port the leader-line layout functions ([d725399](https://github.com/repentsinner/tech_vis/commit/d725399a20fd7922d7553ac2f65e3edaffbe7aa1))
* **python:** port the navigation cube ([c3f3fd5](https://github.com/repentsinner/tech_vis/commit/c3f3fd5a5e6862d4f339963b0150384b56377574))
* **python:** port the scale bar layout ([e7c2c42](https://github.com/repentsinner/tech_vis/commit/e7c2c4224614bb81d22edc5622c45f1ad2b49699))
* **python:** port the typed primitives and their factories ([b56781a](https://github.com/repentsinner/tech_vis/commit/b56781ab34f4a65dce4b11eec40e8594ffbea1c9))
* **python:** port the unit systems and display formats ([afa192b](https://github.com/repentsinner/tech_vis/commit/afa192b31eb4534870fedd4b9d37db22003cd506))
* **python:** port viewport overlay placement ([64de17e](https://github.com/repentsinner/tech_vis/commit/64de17ee703af5586d0b4a2efc1a14271b38261c))
* **style:** add default corner, offset, and size tokens for each overlay ([ed99158](https://github.com/repentsinner/tech_vis/commit/ed9915864b966767a8352bdc1c9437110a60bdff))
* **style:** add marker diameter and sphere detail tokens ([a40f83c](https://github.com/repentsinner/tech_vis/commit/a40f83c16bc8ac86a869efd0f07e6c40ffb07803))
* **style:** add scale bar tick spacing, step hysteresis, and label height tokens ([faaf5b1](https://github.com/repentsinner/tech_vis/commit/faaf5b14bb6269bc083559f56e4d287349742215))

# [0.3.0](https://github.com/repentsinner/tech_vis/compare/v0.2.0...v0.3.0) (2026-11-16)


### Features

* **dart:** draw coordinate frames as scene objects ([5a52318](https://github.com/repentsinner/tech_vis/commit/5a52318058cf6c4f900c5c32da8b6358277fb149))
* **dart:** emit bounding box edges once, as lines ([d789192](https://github.com/repentsinner/tech_vis/commit/d7891923acbe3c3077ff7b9b76a33d3807a6baa2))
* **dart:** use 64-bit vectors and matrices in the public API ([8806770](https://github.com/repentsinner/tech_vis/commit/8806770deb3bf1220b39edcbc5e75977c96f4a71))

# [0.2.0](https://github.com/repentsinner/tech_vis/compare/v0.1.0...v0.2.0) (2026-11-16)


### Bug Fixes

* **dart:** require the vector_math release that has scaleByDouble ([484fd44](https://github.com/repentsinner/tech_vis/commit/484fd44486a76f4967b9592710a252eb5411a203))


### Features

* **dart:** size screen-space elements by depth and add billboard helpers ([a398ad3](https://github.com/repentsinner/tech_vis/commit/a398ad3de1ed880d454bdd55d2bea85ef7691162))

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
