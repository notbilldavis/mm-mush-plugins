# mm-mush-plugins
Some plugins I've made for MUSHclient to use when playing Materia Magica.

I'm still adding to a lot of these so let me know if you see any issues by sending a tell or mail to Oona.

If you have the updatehelper.lua file these will try to download the files you need, but your best bet to avoid errors is to just download everything in the [lua folder](https://github.com/notbilldavis/mm-mush-plugins/tree/main/lua) to the lua folder in your local MUSHclient directory then install the ones you want one at a time. If you forgot a file it should tell you when you install it.

## Affects Buttons

![Image](https://github.com/user-attachments/assets/0b1a8ae0-0dd4-4c08-a141-92fe0da7cf5a)

Customizable panel to add buttons to. Can be tied to specific affects to show when you have an affect active and how much time is left on it.

Optional miniwindow to show your negative affects with expiration.

You can set buttons to be "favorites" which makes the cast favorites button at the top cast all of them that aren't already casted.

Have the SHOW-AFFECT-SPOILERS setting on in game to make sure you get all the events and stuff.

If you use the tabbed-captures plugin you can set affects to get captured when you gain and lose them.

Right click the header to get started adding buttons. You can also use commands like 'affects add/edit/delete/move/etc' to get stuff done as well. Typing 'affects config' will pop open a menu to customize pretty much anything.


## Blackjack Helper

Pretty self-explanitory, turn this on to keep feeding the dealer your vouchers. You have to explicitly turn this on, use responsibly.

## Bosses Killed Sort

![Image](https://github.com/user-attachments/assets/a48565a4-99e6-427a-aae2-5098c7a814f7)

Sort your boss killed list by kill order, will add other sorts like by category or type eventually. Also has a command to export all your marks and bosses into a table all fancy like. See [my OOC page](http://ooc.dune.net/alliance/Oona) for an example.

## Capture Quest

![Image](https://github.com/user-attachments/assets/4f4965aa-b5b4-4436-a88b-7baba0470b0a)

Puts a little quest button on the screen to track your current quest in a collapsable mini window. Will also look the quest up on annwn.info for a little help. Can do a quest hint <phase #> for additional info pulled too. It will save quests in a db so it doesn't try to get it multiple times from the site. Can get weird for quests not found on annwn though. 

Phases that have you visit a room are clickable to use the mapper to do a 'mapper find' easily. The quest number itself can be clicked to open up the annwn page directly.

When you look at a crystal guild map it will automatically look up it's location from the OOC MagicMap and keep track of that too. If you are using the world_map plugin it will put an icon at that location too.

Will also track what your orc pursuer target is and pick up any body parts your target drops. If you use the cooking_helper plugin it will pause your pouch of plenitude automation so you don't accidently drop the part. Will automatically give the orc the body part when you see him afterwards and re-enable your pouch.

Type 'quest time' to see a decent estimation as to when you can do these things again. It will also show in your score next to quest points.

## Collectables

Pick up those pesky collectables and keep track of them as you do. Use a log to get the plate and plushie numbers you already have to add them all in one go, stamps are a little more complicated but still doable.

## Cooking Helper

Does a bunch of things now:

![Image](https://github.com/user-attachments/assets/2283f338-4776-4ccc-be9b-27f13a798298)

Index cards get these hyperlinks to help. Just set your container you keep all your ingredients in (mine is set to 3.trunk in the screenshot) and it can easily cook as many as you have the ingredients for. Also easy to add an entire recipe to the pouch of plenitude tracking.

![Image](https://github.com/user-attachments/assets/e5cd9ca4-e1bd-47fb-aa96-dd5fb823400f)

Keep track of who eats your foods and when. Any npc food trucks will get added when they eat it. You'll have to manually add players. The little 'n' icon next to the recipe will show you what npcs haven't eaten that one yet.

![Image](https://github.com/user-attachments/assets/09c34805-75d5-4e15-85e3-8c843f3f7a14)

Automatically get all the stuff from your pouch of plenitude, put what you track in your container, and drop the rest.

## Curio Sort

![Image](https://github.com/user-attachments/assets/90b9387d-6dab-4eaf-afe5-011bd368367d)

Like the boss sort this sorts your curios by expiration date so you can see the ones you need at the bottom. Also shows you were they are and have handy links if possible. Altars that are expired or expiring soon will be shown when you log on. The columns are adjustable for those with smaller screens. You can sort by any of the columns too if you wanted to do that for some reason. It will also keep track of what you bought even after it has expired.

## Goto Aliases

Just some simple aliases to run around, takes into consideration your location so "goto qm" goes to the right room whether you are in Rune, Maldra, or whevever. Has city gates, qm, next city, daily tourst rep, crystal guild, and orc pursuer as options. I use these with macros to easily get around at the press of a button. Relies on the mapper.

Also lets you shortcut run destinations, so 'run tel' will run you to tellerium without having to type all of 'tellerium'

## Hangman Solver

Uses a random website I found to look up word possiblities. Works really well on "empty"

## Lootable Tracker

![Image](https://github.com/user-attachments/assets/d11bc5de-0ba0-46ea-8bb2-0d29de2a79da)

Track lootables so you know when you can loot them again. Has a couple in there already like the Archon box lootables. Lootables that can be looted again show when you log on.

## Profession Tracker

![Image](https://github.com/user-attachments/assets/765de5e2-a68e-44b0-b3ca-97307516a379)

Track the manuals you need for the Mark of Profession so you know what you already turned in and hopefully which you don't need at all. I pulled this list from the ooc wiki but the newest version hasn't been updated completely so it may be missing manuals. Let me know if you come acrossed one like that so I can add it. If the depressed romantic tells you he wants one that isn't on the list then it will give you the option to send me a tell if I am on.

Type 'prof owned' or 'prof needed' to use.

Also counts up your manuals, folios, and binders when you look in trunks to help artifice.

## Split Scroll

![Image](https://github.com/user-attachments/assets/b041c136-5dc5-491c-ab95-2771f6ae1ce5)

Show a few lines of current output at the bottom when you scroll up so you don't get surprised when looking at your loot or whatever. Gives you a bit old button to jump right back down. MUSH doesn't give a great way to see your scroll position so it's kind of guess work based on your font, screen size, buffer size, etc. 

There is some configuration you will likely need to do. Make sure you have your font option in the config set to the same as your output and then play with the variable count so the split window only shows when you have scrolled and goes away when you are at the bottom.

Will need the configuration_miniwindow.lua file in the MUSHclient\lua folder.

Will try to update itself on disconnect.

## Tabbed Captures

![Image](https://github.com/user-attachments/assets/dc5c0db8-c480-424d-be6a-0da8e4f85e9d)

This works like the capture window you are used to but now you can have as many tabs as you want and separate whatever channels into whatever tabs. Can work with the affects_buttons plugin above to show broadcasted affects.

## World Map

![Image](https://github.com/user-attachments/assets/173d878e-b40d-4799-9f6b-681a2f1be348)

This is a work in progress so isn't really feature complete. It uses the same data as the OOC MagicMap does for better high quality mappage. You can zoom in and out with the mouse wheel and will always keep your location centered. The map will automatically tile just like it does in game.

The capture_quest plugin will display an icon where your crystal is at the moment. Plan on adding different markers you can add by coords or by clicking.