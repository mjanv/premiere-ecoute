//! Asset source: the component icons plus the few extra Lucide icons the player draws.
//! (Lucide is ISC licensed; see `LICENSE-LUCIDE` in the gpui-kit-assets crate.)

use gpui_kit::gpui::{self, AssetSource};

gpui_kit::assets::icon_assets!(ExtraIcons, [SkipBack, SkipForward, Volume2]);

pub struct AppAssets;

impl AssetSource for AppAssets {
    fn load(&self, path: &str) -> gpui::Result<Option<std::borrow::Cow<'static, [u8]>>> {
        if let Some(bytes) = ExtraIcons.load(path)? {
            return Ok(Some(bytes));
        }
        gpui_kit::assets::Assets.load(path)
    }

    fn list(&self, path: &str) -> gpui::Result<Vec<gpui::SharedString>> {
        let mut paths = gpui_kit::assets::Assets.list(path)?;
        paths.extend(ExtraIcons.list(path)?);
        paths.sort();
        paths.dedup();
        Ok(paths)
    }
}
