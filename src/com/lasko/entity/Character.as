﻿package com.lasko.entity
{
	import flash.display.MovieClip;
	import flash.display.BitmapData;
	import flash.geom.Rectangle;
	import flash.geom.Point;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import net.flashpunk.graphics.Spritemap;
 
	import net.flashpunk.Entity;
	
	import com.greensock.motionPaths.RectanglePath2D;
	
	import com.lasko.GameGraphics;
    import com.lasko.util.Utils;
    import com.lasko.entity.CharacterCombat;
	import com.lasko.encounter.CombatCondition;
	import com.lasko.Global;
	import com.lasko.map.Map;
	
	public class Character extends Entity
	{
		private var parentMap:Map;
		public var parentParty:Party;
		
		public var head_cutoff_y:int = 0;

		private var state:Object = { "type": Global.STATE_DOWNSTILL };
		private var pathNodeTimer:Timer;
		private var canAcceptInput:Boolean = true;
		
		private var speed:int = 5;
		public var id:String;
		public var xp:int, hp:int, mp:int, str:int, dex:int, intl:int, level:int;
		public var maxHp:int, maxMp:int;
		public var collisionRectIndex:int;
		private var checkCollisions:Boolean = false;
        private var charCollisionRect:Rectangle;
		public var collidingWith:Object;
		
		public var conditions:Array = new Array();
		private var spells:Array = new Array();
		private var weapons:Array = new Array();
		public var inventory:Inventory;
		public var slots:Object = {"L. Hand": null, "R. Hand": null, "Arms": null, "Torso": null, "Legs": null, "Head": null, "Neck": null};
		
		public var isDosile:Boolean = false;
		private var dosileTimer:Timer;
		public var chaseRange:int = 0;
		
		//for pre-set path - set in map
		private var pathNodes:Array = new Array();
		private var currentPathNode:int = -1;
		
		private var dialog:XML;
		private var portrait:XMLList;
		
		//for joshua - what items is he selling?
		private var shopItems:Array = new Array();
		
		//for wandering logic
		private var wanderParams:Object = {radius: 5, start_x: 0, start_y: 0, x: 0, y: 0, states: {}, statesSum: 0};
		
		public var combat:CharacterCombat;
		public var anim:CharacterAnimation;
		
		public function Character(dataXML:XMLList)
		{
			this.inventory = new Inventory(this.parentParty);
			//frameTimer.addEventListener(TimerEvent.TIMER, changeFrameEvent);
			
			this.setSlot("L. Hand", new Item("Fists"));
			
			//character type
			type = dataXML.type.text();
			
			//stats
			hp = maxHp = dataXML.hp.text();
			mp = maxMp = dataXML.mp.text();
			dex = dataXML.dex.text();
			str = dataXML.str.text();
			name = dataXML.full_name.text();
			id = dataXML.@id;
			level = dataXML.level.text();
			speed = dataXML.speed.text();
			xp = 0;
			
			//spells
			for each (var spellsXML:XML in dataXML.spells.children())
			{
				spells.push(new Spell(spellsXML.@name.toXMLString()));
			}
			
			//dialog?
			if (dataXML.dialog.children().length())
			{
				dialog = XML(dataXML.dialog);
			}
			
			//portrait?
			if (int(dataXML.portrait.@index))
			{
				portrait = dataXML.portrait;
			}
            
            //collision rect from characters.xml
            if (dataXML.collision.children().length()) {
                charCollisionRect = new Rectangle(dataXML.collision.x, dataXML.collision.y, dataXML.collision.width, dataXML.collision.height);
            }
			
			//combat conditions
			for each (var conditionXML:XML in dataXML.conditions.children())
			{
				conditions.push(new CombatCondition(conditionXML, this));
			}
			
			//dimensions
			width = dataXML.width.length() ? dataXML.width.text() : parentMap.getTileWidth();
			height = dataXML.height.length() ? dataXML.height.text() : parentMap.getTileHeight();
			head_cutoff_y = dataXML.head_y.length() ? dataXML.head_y.text() : 24;
			
			//misc
			//only check collisions for carl
			if (id == "carl" || id == "phillip lasko" || id == "townsman")
			{
				checkCollisions = true;
			}
			
			combat = new CharacterCombat(this);
			anim = new CharacterAnimation(this, dataXML);
			
			//flashpunk
			var spritemap:Spritemap = new Spritemap(GameGraphics.carlFrames, 48, 48);
			spritemap.setFrame(0, 0);
			spritemap.visible = true;
			spritemap.x = 0;
			spritemap.y = 0;
			this.addGraphic(spritemap);
			
		}
		
		public function setParty(party:Party):void
		{
			this.parentParty = party;
		}
		
				
		public function addShopItems(itemsString:String):void
		{
			for each (var itemId:String in itemsString.split(","))
			{
				var itemXML:XML = XML(Global.itemsXML.item.(@id == itemId));
				var item:Item = new Item(itemXML.@name);
				item.setIcons(itemXML.icons.small, itemXML.icons.big);
				
				shopItems.push(item);
			}
		}
		
		public function getShopItems():Array
		{
			return (shopItems);
		}
		
		public function setState(type:int, params:Object = null):void
		{
			if (params && !params.force && 
				(type == Global.STATE_LEFTWALK && state.type == Global.STATE_LEFTWALK || type == Global.STATE_RIGHTWALK && state.type == Global.STATE_RIGHTWALK || 
				type == Global.STATE_UPWALK && state.type == Global.STATE_UPWALK || type == Global.STATE_DOWNWALK && state.type == Global.STATE_DOWNWALK)) { return; }
			//not sure if this should set the state only if it's already that state or not
            //if(this.state.type != type) { 
                var obj:Object = {"type": type};
                for (var param:Object in params)
                {
					obj[param] = params[param];
                }
                this.state = obj;
                anim.setAnimState(type);
            //}
		}
		
		public function getState():Object
		{
			return (state);
		}
		
		public function getStateName():String
		{
			return (state.type);
		}
		
        public function tick():void
        {
            if (state.type) {
                switch(Number(state.type)) {
                    case Global.STATE_UPWALK:
						
						//update y coordinate
						y -= speed;
						if (y <= state.target * parentMap.getTileHeight()) { 
							anim.changeFrameEvent();
							if (this.state.stop) { 
								setState(Global.STATE_UPSTILL);
								canAcceptInput = true;
							} else { 
								setState(Global.STATE_UPWALK, { target: state.target - 1, force:true } );
							}
						}
						
					
						
                    break;
                    case Global.STATE_DOWNWALK:
                    
						//update y coordinate
						y += speed;
						if (y >= state.target * parentMap.getTileHeight()) { 
							anim.changeFrameEvent();
							if (this.state.stop) { 
								setState(Global.STATE_DOWNSTILL);
								canAcceptInput = true;
							} else { 
								setState(Global.STATE_DOWNWALK, { target: state.target + 1, force:true } );
							}
						}
						
						
                    break;                    
                    case Global.STATE_LEFTWALK:

						//update x coordinate
						x -= speed;
						if (x <= state.target * parentMap.getTileWidth()) { 
							anim.changeFrameEvent();
							if (this.state.stop) { 
								setState(Global.STATE_LEFTSTILL);
								canAcceptInput = true;
							} else { 
								setState(Global.STATE_LEFTWALK, { target: state.target - 1, force:true } );
							}
						}
						
					
						
                    break;
					case Global.STATE_RIGHTWALK:

						//update x coordinate
						x += speed;
						if (x >= state.target * parentMap.getTileWidth()) { 
							anim.changeFrameEvent();
							if (this.state.stop) { 
								setState(Global.STATE_RIGHTSTILL);
								canAcceptInput = true;
							} else { 
								setState(Global.STATE_RIGHTWALK, { target: state.target + 1, force:true } );
							}
						}
						

                    break;
                }			
            }
        }
        
		public function updateFrame():void
		{
		
		}
		
		public function updatePosition():void
		{
			if (pathNodes.length && !pathNodeTimer)
			{
				//not currently in path -- go to first node
				if (currentPathNode == -1)
				{
					currentPathNode = 0;
				}
				
				var node:Object = pathNodes[currentPathNode];
				if (x > node.x)
				{ //right of
					//moveLeft();
					if (x < node.x)
					{
						x = node.x;
					}
				}
				else if (x < node.x)
				{ //left of
					//moveRight();
					if (x > node.x)
					{
						x = node.x;
					}
				}
				if (y > node.y)
				{ //below
					//moveUp();
					if (y < node.y)
					{
						y = node.y;
					}
				}
				else if (y < node.y)
				{ //above
					//moveDown();
					if (y > node.y)
					{
						y = node.y;
					}
				}
				
				if (x == node.x && y == node.y)
				{
					if (currentPathNode++ >= pathNodes.length - 1)
					{
						currentPathNode = 0;
					}
					
					//if node has delay, set up timer
					if (node.delay)
					{
						anim.setDefaultAnimState();
						pathNodeTimer = new Timer(node.delay, 1);
						pathNodeTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent):void
							{
								pathNodeTimer.stop();
								pathNodeTimer = null;
							});
						pathNodeTimer.start();
					}
				}
			}
			else if (state.type == 'following')
			{
				switch (state.target.animState)
				{
					case "rightwalk": 
						if (x < state.target.x - width)
						{
							//moveRight();
						}
						if (y < state.target.y)
						{
							//moveDown();
						}
						else if (y > state.target.y)
						{
							//moveUp();
						}
						break;
					case "leftwalk": 
						if (x > state.target.x + state.target.width)
						{
							//moveLeft();
						}
						if (y < state.target.y)
						{
							//moveDown();
						}
						else if (y > state.target.y)
						{
							//moveUp();
						}
						break;
					case "downwalk": 
						if (y < state.target.y - height)
						{
							//moveDown();
						}
						if (x < state.target.x)
						{
							//moveRight();
						}
						else if (x > state.target.x)
						{
							//moveLeft();
						}
						break;
					case "upwalk": 
						if (y > state.target.y + height)
						{
							//moveUp();
						}
						if (x < state.target.x)
						{
							//moveRight();
						}
						else if (x > state.target.x)
						{
							//moveLeft();
						}
						break;
					default: 
						anim.setDefaultAnimState();
						break;
				}
			}
			else if (state.type == 'wandering')
			{
				if (Utils.randRange(0, 75) == 1)
				{
					var rand:int = Utils.randRange(0, wanderParams.statesSum);
					var sum:int = 0;
					for (var s:String in wanderParams.states)
					{
						sum += wanderParams.states[s];
						if (sum >= rand)
						{
							trace('setting to ' + s);
							anim.setAnimState(Number(s));
							break;
						}
					}
					
				}
				
				switch (anim.animState)
				{
					case "rightwalk": 
						//moveRight();
						break;
					case "leftwalk": 
						//moveLeft();
						break;
					case Global.STATE_DOWNWALK: 
						//moveDown();
						break;
					case "upwalk": 
						//moveUp();
						break;
					case 'downblink': 
					case 'leftblink': 
					case 'rightblink':
						
						break;
					default: 
						//anim.setDefaultAnimState();
						break;
				}
			}
		}
		
		public function setMovementType(type:String, params:Object = null):void
		{
			switch (type)
			{
				case 'wander': 
					wanderParams.x = wanderParams.start_x = x;
					wanderParams.y = wanderParams.start_y = y;
					wanderParams.radius = params && params.radius ? params.radius : 5;
					wanderParams.states = [];
					wanderParams.states[Global.STATE_RIGHTWALK] = 50;// Global.STATE_LEFTWALK: 50, Global.STATE_UPWALK: 50, Global.STATE_DOWNWALK: 50, Global.STATE_UPSTILL: 50, Global.STATE_DOWNSTILL: 100, Global.STATE_RIGHTSTILL: 60, Global.STATE_LEFTSTILL: 60 }
					
					wanderParams.statesSum = 0;
					for each (var num:int in wanderParams.states)
					{
						wanderParams.statesSum += num;
					}
					
					setState(Global.STATE_WANDERING);
					break;
			}
		}
		
		public function getSlots():Object
		{
			return (slots);
		}
		
		public function setSlot(slot:String, item:Item):void
		{
			slots[slot] = item;
			trace('set slot ' + slot + ' to ' + item.name + ' for character ' + name);
		}
		
		public function getSlot(slot:String):Item {
			return slots[slot];
		}
		
		public function getSpells():Array
		{
			return (spells);
		}
		
		public function getDialog():XML
		{
			return (dialog);
		}
		
		public function hasDialog():Boolean
		{
			return (dialog != null);
		}
		
		public function getPortrait():XMLList
		{
			return (portrait);
		}
		
		public function hasSpell():Boolean
		{
			return (spells.length > 0);
		}
		
		public function addPathNode(xPos:int, yPos:int, pathIndex:int, pathDelay:int, pathSpeed:int):void
		{
			pathNodes[pathIndex - 1] = {x: xPos, y: yPos, index: pathIndex, speed: pathSpeed, delay: pathDelay};
		}
		
		public function addChaseRange(value:int):void
		{
			chaseRange = value;
		}
		
		private function die():void
		{
			anim.setAnimState(Global.STATE_DEAD);
			setState(Global.STATE_DEAD);
		}
		
		public function setHP(value:int):void
		{
			hp = value;
			if (hp <= 0) {
				hp = 0;
				die();
			} else if (hp > maxHp) {
				hp = maxHp;
			}
			trace(name + "'s hp is now " + hp);
		}
		
		public function setMP(value:int):void
		{
			mp = value;
			if (mp <= 0) {
				mp = 0;
			} else if (mp > maxMp) {
				mp = maxMp;
			}
			trace(name + "'s mp is now " + mp);
		}
		
		public function addHP(value:int):void {
			setHP(this.hp + value);
		}
		
		public function addMP(value:int):void {
			setMP(this.mp + value);
		}
		
		public function getHP():int
		{
			return (hp);
		}
		
		public function getMaxHP():int
		{
			return (maxHp);
		}
		
		public function getMP():int
		{
			return (mp);
		}
		
		public function getMaxMP():int
		{
			return (maxMp);
		}
		
		public function setDosile():void
		{
			isDosile = true;
			dosileTimer = new Timer(100, 0);
			dosileTimer.addEventListener(TimerEvent.TIMER, dosileTimerHandler);
			dosileTimer.start();
		}
		
		private function dosileTimerHandler(e:TimerEvent):void
		{
			//if (!rect.intersects(Global.game.getParty().leader.rect))
			//{
			//	e.target.stop();
			//	dosileTimer = null;
			//	isDosile = false;
			//}
		}
	}
}