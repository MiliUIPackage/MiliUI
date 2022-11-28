# AppearanceTooltip

## [v37](https://github.com/kemayo/wow-appearancetooltip/tree/v37) (2022-11-20)
[Full Changelog](https://github.com/kemayo/wow-appearancetooltip/compare/v36...v37) [Previous Releases](https://github.com/kemayo/wow-appearancetooltip/releases)

- Remove shoulder armor when trying on helmets  
- Use a 0 second timer after configuring the model before trying on items  
    This fixes display in zoomed out mode, which now seems to require this.  
    Fixes #12  
- Fix Undead cameras not zooming  
    f25a8ca09774eb2483f35bfae5e046e6eea4d83f changed the name (because it  
    changed in Blizzard's database), and I didn't update it in the race map  
    Refs #12  
- Adjust overlay on sets list because of the new 5-variant sets  
