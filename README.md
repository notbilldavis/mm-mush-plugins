# mm-mush-plugins
Some plugins I've made for MUSHclient to use when playing Materia Magica.

I'm still adding to a lot of these so let me know if you see any issues.

## Affects Buttons

![Image](https://github.com/user-attachments/assets/0b1a8ae0-0dd4-4c08-a141-92fe0da7cf5a)

Customizable panel to add buttons to. Can be tied to specific affects to show when you have an affect active and how much time is left on it.

You will need to have the affectsbuttons_miniwindow.lua, badaffects_miniwindow.lua, and configuration_miniwindow.lua files in your MUSHclient\lua folder or this will crap out.

Also have the SHOW-AFFECT-SPOILERS setting on in game to make sure you get all the events and stuff.

## Blackjack Helper

Pretty self-explanitory, turn this on to keep feeding the dealer your vouchers. You have to explicitly turn this on, use responsibly.

## Bosses Killed Sort

![Image](https://github.com/user-attachments/assets/a48565a4-99e6-427a-aae2-5098c7a814f7)

Sort your boss killed list by kill order, will add other sorts like by category or type eventually. Also has a command to export all your bosses into a table all fancy like. See [my OOC page](http://ooc.dune.net/alliance/Oona) for an example.

## Collectables

Pick up those pesky collectables and keep track of them as you do. Use a log to get the plate and plushie numbers you already have to add them all in one go, stamps are a little more complicated.

## Cooking Helper

Does a couple things, firstly it adds some hyperlinks when you look at an index card to search your inventory for the ingredients or get them from a specific container. This is specific to me so I'll add some customization eventually. Secondly it lets you search a database for ingredient locations, I pulled this from the public spreadsheet so it may need some work and updates. Thirdly you can track who eats your food, it will track NPC food trucks automatically and you can manually add whoever.

## Curio Sort

Like the boss sort this sorts your curios by expiration date so you can see the ones you need at the bottom. Also shows you were they are and have handy links if possible. Altars expiring soon will be shown when you log on.

## Goto Aliases

Just some simple aliases to run around, takes into consideration your location so "goto qm" goes to the right room whether you are in Rune, Maldra, or whevever. Has city gates, qm, next city, daily tourst rep, crystal guild, and orc pursuer as options. I use these with macros to easily get around at the press of a button. Relies on the mapper.

## Hangman Solver

Uses a random website I found to look up word possiblities. Works really well on "empty"

## Lootable Tracker

Track lootables so you know when you can loot them again. Has a couple in there already like the Archon box lootables. It's a little finicky though, it should try to automatically loot again to update the timer but sometimes it doesn't. Manually re-loot until I fix it I guess. Lootables that can be looted again show when you log on.

## Capture Quest

Puts a little quest button on the screen to track your current quest in a collapsable mini window. Will also look the quest up on annwn.info for a little help. Can do a quest hint <phase #> for additional info pulled too. It will save quests in a db so it doesn't try to get it multiple times from the site. Can get weird for quests not found on annwn though. Will be adding customization to this soon too.

Will need the quest_miniwindow.lua and questsearcher.lua files in the MUSHclient\lua folder.

## Split Scroll

![Image](https://github.com/user-attachments/assets/b041c136-5dc5-491c-ab95-2771f6ae1ce5)

Show a few lines of current output at the bottom when you scroll up so you don't get surprised when looking at your loot or whatever. Gives you a bit old button to jump right back down. MUSH doesn't give a great way to see your scroll position so it's kind of guess work based on your font, screen size, buffer size, etc. Will be adding a configuration to this to make it hopefully work for everyone with some adjusting.

Will need the configuration_miniwindow.lua file in the MUSHclient\lua folder
