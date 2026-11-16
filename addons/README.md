# Third-party addons

| Addon | Version | Source | License | Notes |
|---|---|---|---|---|
| `gdUnit4/` | 6.2.3 (tag `v6.2.3`, commit `f2e4f8679ebd28e27ef523a4fb7b09e8337bfce9`) | https://github.com/MikeSchulze/gdUnit4 | MIT (`gdUnit4/LICENSE`) | Copied from `addons/gdUnit4` of the tag, without the addon's own `test/` folder (only used by its update-notifier debug path). |
| `zylann.voxel/` | Voxel Tools GDExtension 1.7 (release tag `v1.7x`, `GodotVoxelExtension.zip` SHA256 `600737572a5e25541ba6f503e842a3717ba19afafa5474510a6ceff995a1d2d8`) | https://github.com/Zylann/godot_voxel | MIT (`zylann.voxel/LICENSE.md`) | Only the manifest, icons and license are committed. Run `ci/fetch_voxel.sh` after cloning to install the desktop binaries into `zylann.voxel/bin/` (gitignored). |

Update procedure: replace the folder from a verified release tag, record tag and commit here, and run the full headless suite.
