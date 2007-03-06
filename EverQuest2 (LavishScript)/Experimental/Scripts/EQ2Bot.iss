;-----------------------------------------------------------------------------------------------
; EQ2Bot.iss Version 2.5.3 Updated: 01/21/07 by pygar
;
;
; Lots of changes, documentation comming
;
;Fixed a bug causing spells to be interupted occasionally
;	
;
; Description:
; ------------
; Automated BOT for any class.
; Syntax: run eq2bot
;
;===================================================
;===		Keyboard Configuration	        ====
;===================================================
variable string forward=w
variable string backward=s
variable string strafeleft=a
variable string straferight=d
variable string endbot=f11
;===================================================

;===================================================
;===		Variable Declarations	        ====
;===================================================
variable EQ2BotObj EQ2Bot
variable ActorCheck Mob
variable(global) bool CurrentTask=TRUE
variable bool IgnoreEpic
variable bool IgnoreNamed
variable bool IgnoreHeroic
variable bool IgnoreRedCon
variable bool IgnoreOrangeCon
variable bool IgnoreYellowCon
variable bool IgnoreWhiteCon
variable bool IgnoreBlueCon
variable bool IgnoreGreenCon
variable bool IgnoreGreyCon
variable filepath mainpath="${LavishScript.HomeDirectory}/Scripts/"
variable string spellfile
variable string charfile
variable string SpellType[400]
variable int AssistHP
variable string MainAssist
variable string MainTankPC
variable bool MainAssistMe=FALSE
variable string OriginalMA
variable string OriginalMT
variable bool AutoSwitch
variable bool AutoMelee
variable bool AutoPull
variable bool AutoLoot
variable bool LootAll
variable int KillTarget
variable string Follow
variable string PreAction[40]
variable int PreMobHealth[40,2]
variable int PrePower[40,2]
variable int PreSpellRange[40,5]
variable string Action[40]
variable int MobHealth[40,2]
variable int Power[40,2]
variable int SpellRange[40,5]
variable string PostAction[20]
variable int PostSpellRange[20,5]
variable bool stealth=FALSE
variable bool direction=TRUE
variable float targetheading
variable bool disablebehind=FALSE
variable bool disablefront=FALSE
variable int movetimer
variable bool isstuck=FALSE
variable bool MainTank=FALSE
variable float HomeX
variable float HomeZ
variable int obstaclecount
variable int LootX
variable int LootY
variable int pathindex
variable string World
variable float WPX
variable float WPY
variable float WPZ
variable string NearestPoint
variable bool checkfollow=FALSE
variable string PullSpell
variable int PullRange
variable int ScanRange
variable bool engagetarget=FALSE
variable bool islooting=FALSE
variable int CurrentPull
variable int TotalPull
variable bool pathdirection=0
variable bool Following
variable int Deviation
variable int Leash
variable bool movingtowp
variable bool pulling
variable bool priesthaspower=FALSE
variable int stuckcnt
variable int grpcnt
variable bool movinghome
variable bool haveaggro=FALSE
variable bool shwlootwdw
variable bool hurt
variable int currenthealth[5]
variable int changehealth[5]
variable int oldhealth[5]
variable int healthtimer[5]
variable int chgcnt[5]
variable int tempgrp
variable bool KeepReactive
variable int chktimer
variable int starttimer=${Time.Timestamp}
variable bool avoidhate
variable bool lostaggro
variable int aggroid
variable bool usemanastone
variable int mstimer=${Time.Timestamp}
variable int StartLevel=${Me.Level}
variable bool PullNonAggro
variable bool checkadds
variable string DCDirection=Finish
variable string reactivespell
variable string Harvesting
variable bool PauseBot=FALSE
variable bool StartBot=FALSE
variable bool CloseUI
variable int PowerCheck
variable int HealthCheck
variable int PullPoint
variable float PositionHeading
variable bool PullWithBow
variable bool LootConfirm
variable bool CheckPriestPower
variable int LootWndCount
variable bool NoEQ2BotStance=0
;===================================================

;===================================================
; Define the PathType
; 0 = Manual Movement
; 1 = Minimum Movement - Home Point Set
; 2 = Camp - Follow Small Nav Path with multiple Pull Points
; 3 = Dungeon Crawl - Follow Nav Path: Start to Finish
; 4 = Auto Hunting - Pull nearby Mobs within a Maximum Range

variable int PathType
;===================================================

#include ${LavishScript.HomeDirectory}/Scripts/EQ2Bot/Class Routines/${Me.SubClass}.iss
#include ${LavishScript.HomeDirectory}/Scripts/moveto.iss

function main()
{
	variable int tempvar
	variable int tempvar1
	variable int tempvar2
	variable string tempnme

	Turbo 1000
	
	;Script:Squelch
	;Script:EnableProfiling
	
	EQ2Bot:Init_Config
	EQ2Bot:Init_Triggers
	EQ2Bot:Init_Character
	EQ2Bot:Init_UI


	call Class_Declaration

	call CheckManaStone

	do
	{
		waitframe
		call ProcessTriggers
	}
	while !${StartBot}

	if ${KeepReactive}
	{
		grpcnt:Set[${Me.GroupCount}]
		tempgrp:Set[1]
		do
		{
			switch ${Me.Group[${tempgrp}].Class}
			{
				case priest
				case cleric
				case templar
				case inquisitor
				case druid
				case fury
				case warden
				case shaman
				case defiler
				case mystic
					tempvar:Set[1]
					spellfile:Set[${mainpath}EQ2Bot/Spell List/${Me.Group[${tempgrp}].Class}.xml]
					do
					{
						tempnme:Set["${SettingXML[${spellfile}].Set[${Me.Group[${tempgrp}].Class}].Key[${tempvar}]}"]

						if ${Arg[1,${tempnme}]}>${Me.Group[${tempgrp}].Level}
						{
							break
						}

						if ${Arg[2,${tempnme}]}==7
						{
							reactivespell:Set[${SettingXML[${spellfile}].Set[${Me.Group[${tempgrp}].Class}].GetString["${tempnme}"]}]
						}
					}
					while ${tempvar:Inc}<=${SettingXML[${spellfile}].Set[${Me.Group[${tempgrp}].Class}].Keys}
					break
			}
		}
		while ${tempgrp:Inc}<${grpcnt}
	}

	; The following 3 scripts are Initialized which are customizable
	call Buff_Init
	call Combat_Init
	call PostCombat_Init

	do
	{
		if ${EQ2.Zoning}
		{
			KillTarget:Set[]
			do
			{
				wait 50
			}
			while ${EQ2.Zoning}
			wait 50
		}

		if ${Me.ToActor.Power}<85 && ${Me.ToActor.Health}>80 && ${Me.Inventory[ExactName,ManaStone](exists)} && ${usemanastone}
		{
			if ${Math.Calc[${Time.Timestamp}-${mstimer}]}>70
			{
				Me.Inventory[ExactName,ManaStone]:Use
				mstimer:Set[${Time.Timestamp}]
			}
		}

		; Process Pre-Combat Scripts
		tempvar:Set[1]
		do
		{
			do
			{
				waitframe
			}
			while ${Following} && ${FollowTask}==3

			; For dungeon crawl and not pulling, then follow the nav path instead of using follow.
			if ${PathType}==3 && !${AutoPull}
			{
				if ${Actor[${MainAssist}](exists)}
				{
					target ${MainAssist}
					wait 10 ${Target.ID}==${Actor[${MainAssist}].ID}
				}

				; Need to make sure we are close to the puller. Assume Puller is Main Tank for Dungeon Crawl.
				if !${Me.TargetLOS} && ${Target.Distance}>10
				{
					call MovetoMaster
				}
				elseif ${Target.Distance}>10
				{
					call FastMove ${Actor[${MainAssist}].X} ${Actor[${MainAssist}].Z} ${Math.Rand[3]:Inc[3]}
				}
			}

			if !${MainTank}
			{
				if (${Actor[${MainAssist}].Target.Type.Equal[NPC]} || ${Actor[${MainAssist}].Target.Type.Equal[NamedNPC]}) && ${Actor[${MainAssist}].Target.InCombatMode}
				{	
					KillTarget:Set[${Actor[${MainAssist}].Target.ID}]
				}

				if ${Following}
				{
					if ${Mob.Target[${KillTarget}]}
					{
						FollowTask:Set[2]
						WaitFor ${Script[follow].Variable[pausestate]} 30
						if ${AutoMelee} 
						{
							call FastMove ${Actor[${MainAssist}].X} ${Actor[${MainAssist}].Z} ${Math.Rand[5]:Inc[5]}
						}
						else
						{
							call FastMove ${Actor[${MainAssist}].X} ${Actor[${MainAssist}].Z} 10
						}

						if ${Me.IsMoving}
						{
							press -release ${forward}
							wait 20 !${Me.IsMoving}
						}
						FollowTask:Set[1]
					}
				}

				if ${KillTarget} && ${Actor[${KillTarget}].Health}<=${AssistHP} && ${Actor[${KillTarget}].Health}>1 && ${Actor[${KillTarget},radius,35](exists)}
				{
					if ${Mob.Target[${KillTarget}]}
					{
						call Combat
					}
				}

			}

			if ${PathType}==4 && ${MainTank}
			{
				if ${Me.ToActor.Power}<${PowerCheck} || ${Me.ToActor.Health}<${HealthCheck}
				{
					call ScanAdds
				}
			}

			; Do Pre-Combat Script if there is no mob nearby
			if !${Mob.Detect} || (${MainTank} && ${Me.GroupCount}!=1)
			{
				call Buff_Routine ${tempvar}
				
				;allow class file to set a var to override eq2bot stance / pet casting
				if ${NoEQ2BotStance}
				{
					switch ${Me.Archetype}
					{
						case scout
							if ${MainTank} && ${Me.GroupCount}!=1
							{
								if ${Me.Maintained[${SpellType[290]}](exists)}
								{
									Me.Maintained[${SpellType[290]}]:Cancel
								}
								call CastSpellRange 295 0 0 0 0 0 0 1
							}
							else
							{
								if ${Me.Maintained[${SpellType[295]}](exists)}
								{
									Me.Maintained[${SpellType[295]}]:Cancel
								}

								call CastSpellRange 290 0 0 0 0 0 0 1
							}

							if !${Me.Effect[Pathfinding](exists)} && !${Me.Effect[Selo's Accelerating Chorus](exists)}
							{
								call CastSpellRange 302 0 0 0 0 0 0 1
							}
							break

						case fighter
							if ${MainTank} && ${Me.GroupCount}!=1
							{
								if ${Me.Maintained[${SpellType[290]}](exists)}
								{
									Me.Maintained[${SpellType[290]}]:Cancel
								}
								call CastSpellRange 295 0 0 0 0 0 0 1
							}
							else
							{
								if ${Me.Maintained[${SpellType[295]}](exists)}
								{
									Me.Maintained[${SpellType[295]}]:Cancel
								}

								call CastSpellRange 290 0 0 0 0 0 0 1
							}
						case mage
							if ${MainTank} && ${Actor[MyPet](exists)}
							{
								if ${Me.Maintained[${SpellType[290]}](exists)}
								{
									Me.Maintained[${SpellType[290]}]:Cancel
								}
								call CastSpellRange 295
							}
							elseif ${Actor[MyPet](exists)}
							{
								if ${Me.Maintained[${SpellType[295]}](exists)}
								{
									Me.Maintained[${SpellType[295]}]:Cancel
								}

								call CastSpellRange 290
							}

						break

						case priest
							break
						case default
							break
					}
				}
				
			}
			call Buff_Routine ${tempvar}
		}
		while ${tempvar:Inc}<=40

		if ${AutoPull}
		{
			EQ2Bot:PriestPower

			if ${PathType}==2 && ${priesthaspower} && ${Me.Ability[${PullSpell}].IsReady} && ${Me.ToActor.Power}>${PowerCheck} && ${Me.ToActor.Health}>${HealthCheck}
			{
				PullPoint:Set[${EQ2Bot.ScanWaypoints}]
				if ${PullPoint}
				{
					pulling:Set[TRUE]
					call MovetoWP "Pull ${PullPoint}"
					EQ2Execute /target_none

					; Make sure we are close to our home point before we begin combat
					if ${Math.Distance[${Me.X},${Me.Z},${HomeX},${HomeZ}]}>5
					{
						pulling:Set[TRUE]
						call MovetoWP "Start"
						pulling:Set[FALSE]
					}
				}
			}
			elseif ${PathType}==3 && ${priesthaspower} && ${Me.Ability[${PullSpell}].IsReady} && ${Me.ToActor.Power}>${PowerCheck} && ${Me.ToActor.Health}>${HealthCheck} && ${AutoPull}
			{
				pulling:Set[TRUE]
				call MovetoWP "${DCDirection}"
				EQ2Execute /target_none
			}

			if ${Mob.Detect} || (${Me.Ability[${PullSpell}].IsReady} && ${Me.ToActor.Power}>${PowerCheck} && ${Me.ToActor.Health}>${HealthCheck})
			{
				if ${PathType}==4 && !${Me.InCombat}
				{
					if ${priesthaspower}
					{
						call Pull any
						if ${engagetarget}
						{
							wait 10
							if ${Mob.Target[${Target.ID}]}
							{
								call Combat
							}
						}
					}
				}
				else
				{
					if ${priesthaspower}
					{
						call Pull any
						if ${engagetarget}
						{
							call Combat
						}
					}
				}
			}
		}
		call ProcessTriggers

		; Check if we have leveled and reset XP Calculations in UI
		if ${Me.Level}>${StartLevel} && !${CloseUI}
		{
			SettingXML[Scripts/EQ2Bot/Character Config/${Me.Name}.xml].Set[Temporary Settings]:Set["StartXP",${Me.Exp}]:Save
			SettingXML[Scripts/EQ2Bot/Character Config/${Me.Name}.xml].Set[Temporary Settings]:Set["StartTime",${Time.Timestamp}]:Save
		}

		; Check if we have leveled and reload spells
		if ${Me.Level}>${StartLevel} && ${Me.Level}<70
		{
			EQ2Bot:Init_Config
			call Buff_Init
			call Combat_Init
			call PostCombat_Init
			StartLevel:Set[${Me.Level}]
		}

		if (${Actor[${MainAssist}].Health}==-99 && !${MainTank}) || (${MainAssist.NotEqual[${OriginalMA}]} && ${Actor[${OriginalMA}].Health}==-99)
		{
			EQ2Bot:MainAssist_Dead
		}

		if (${Actor[${MaintTankPC}].Health}==-99 && !${MainTank}) || (${MaintTankPC.NotEqual[${OriginalMT}]} && ${Actor[${OriginalMT}].Health}==-99)
		{
			EQ2Bot:MainTank_Dead
		}		

		; Check that we are close to MainAssist if we are following and not in combat
		if ${Following} && ${Actor[${MainAssist}].Distance}>10 && ${Script[follow].Variable[pausestate]}
		{
			FollowTask:Set[1]
			wait 20
		}

		if ${EQ2UIPage[Inventory,Loot].Child[text,Loot.LottoTimerDisplay].Label}>0 && ${EQ2UIPage[Inventory,Loot].Child[text,Loot.LottoTimerDisplay].Label}<60
		{ 
			if ${LootAll} 
			{
				EQ2UIPage[Inventory,Loot].Child[button,Loot.button RequestAll]:LeftClick 
				wait 5 

				if ${EQ2UIPage[Choice,RoundedGrouper].Child[button,Choice.Choice1](exists)} 
				{ 
				     LootWndCount:Set[1] 
				     do 
				     { 
					  if (${LootWindow.Item[LootWndCount].Lore} || ${LootWindow.Item[LootWndCount].NoTrade}) && ${LootConfirm} 
					  { 
					       EQ2UIPage[Choice,RoundedGrouper].Child[button,Choice.Choice1]:LeftClick 
					  } 
					  else 
					  { 
					       EQ2UIPage[Choice,RoundedGrouper].Child[button,Choice.Choice2]:LeftClick 
					  } 
				     } 
				     while ${LootCount:Inc} <= ${LootWindow.NumItems} 
				} 
			} 
			else
			{
				EQ2UIPage[Inventory,Loot].Child[button,Loot.button Decline]:LeftClick 
			}
		}
	}
	while ${CurrentTask}
}

function CheckManaStone()
{
	variable int tempvar

	Me:CreateCustomInventoryArray[nonbankonly]

	do
	{
		if ${Me.CustomInventory[${tempvar}].Name.Equal[Manastone]}
		{
			usemanastone:Set[TRUE]
			return
		}
	}
	while ${tempvar:Inc}<=${Me.CustomInventoryArraySize}

	usemanastone:Set[FALSE]
}

function CastSpellRange(int start, int finish, int xvar1, int xvar2, int targettobuff, int notall, int refreshtimer, bool castwhilemoving)
{
	variable bool fndspell
	variable int tempvar=${start}
	variable int originaltarget

	if ${Me.ToActor.Power}<5
	{
		return -1
	}

	if ${Me.IsMoving} && !${castwhilemoving}
	{
		return -1
	}

	do
	{
		if ${SpellType[${tempvar}].Length}
		{
			
			if ${Me.Ability[${SpellType[${tempvar}]}].IsReady}
			{
				if ${targettobuff}
				{
					fndspell:Set[FALSE]
					tempgrp:Set[1]
					do
					{
						if ${Me.Maintained[${tempgrp}].Name.Equal[${SpellType[${tempvar}]}]} && ${Me.Maintained[${tempgrp}].Target.ID}==${targettobuff} && (${Me.Maintained[${tempgrp}].Duration}>${refreshtimer} || ${Me.Maintained[${tempgrp}].Duration}==-1)
						{
							fndspell:Set[TRUE]
							break
						}
					}
					while ${tempgrp:Inc}<=${Me.CountMaintained}

					if !${fndspell}
					{
						if !${Actor[${targettobuff}](exists)} || ${Actor[${targettobuff}].Distance}>35
						{
							return -1
						}

						if ${xvar1} || ${xvar2}
						{
							call CheckPosition ${xvar1} ${xvar2}
						}

						if ${Target(exists)}
						{
							originaltarget:Set[${Target.ID}]
						}

						if ${targettobuff(exists)}
						{
							if !(${targettobuff}==${Target.ID}) && !(${targettobuff}==${Target.Target.ID} && ${Target.Type.Equal[NPC]}) 
							{
								target ${targettobuff}
								wait 10 ${Target.ID}==${targettobuff}
							}
						}

						call CastSpell "${SpellType[${tempvar}]}" ${tempvar} ${castwhilemoving}

						if ${Actor[${originaltarget}](exists)}
						{
							target ${originaltarget}
							wait 10 ${Target.ID}==${originaltarget}
						}

						if ${notall}==1
						{
							return -1
						}
					}
				}
				else
				{
					if !${Me.Maintained[${SpellType[${tempvar}]}](exists)} || (${Me.Maintained[${SpellType[${tempvar}]}].Duration}<${refreshtimer} && ${Me.Maintained[${SpellType[${tempvar}]}].Duration}!=-1)
					{
						if ${xvar1} || ${xvar2}
						{
							call CheckPosition ${xvar1} ${xvar2}
						}

						call CastSpell "${SpellType[${tempvar}]}" ${tempvar} ${castwhilemoving}

						if ${notall}==1
						{
							return ${Me.Ability[${SpellType[${tempvar}]}].TimeUntilReady}
						}
					}
				}
			}
		}

		if !${finish}
		{
			return ${Me.Ability[${SpellType[${tempvar}]}].TimeUntilReady}
		}
	}
	while ${tempvar:Inc}<=${finish}

	return ${Me.Ability[${SpellType[${tempvar}]}].TimeUntilReady}
}

function CastSpell(string spell, int spellid, bool castwhilemoving)
{

	if ${Me.IsMoving} && !${castwhilemoving}
	{
		return
	}
		
	Me.Ability[${spell}]:Use
	
	;if spells are being interupted do to movement
	;increase the wait below slightly. Default=10
	wait 10
	
	do
	{
		waitframe
	}
	while ${Me.CastingSpell}
	
	return SUCCESS
}

function Combat()
{
	variable int tempvar

	movinghome:Set[FALSE]
	avoidhate:Set[FALSE]
	FollowTask:Set[2]

	; Make sure we are still not moving when we enter combat
	if ${Me.IsMoving}
	{
		press -release ${forward}
		press -release ${backward}
		wait 20 !${Me.IsMoving}
	}

	do
	{
		if !${MainTank}
		{
			target ${KillTarget}
		}

		if ${Target.ID}!=${Me.ID} && ${Target(exists)}
		{
			face ${Target.X} ${Target.Z}

		}
		
		; Main Tank needs to turn the mob away from the rest of the group
		if ${PathType}==2 && ${MainTank}
		{
			;removed to stop excess movement
		}

		do
		{
			if !${Mob.ValidActor[${Target.ID}]} || !${Actor[${Target.ID}].InCombatMode}
			{
				break
			}

			if ${Target.ID}!=${Me.ID} && ${Target(exists)}
			{
				face ${Target.X} ${Target.Z}

			}

			tempvar:Set[1]
			do
			{
				call ProcessTriggers

				if ${PathType}==4 && ${MainTank}
				{
					call ScanAdds
				}

				if ${MainTank}
				{
					if ${Target.Target.ID}==${Me.ID} 
					{
						call CheckMTAggro
					}
					else
					{
						call Lost_Aggro ${Target.ID}
					}
				}
				else
				{
					Mob:CheckMYAggro
					
					if ${Actor[${MainAssist}].Health}==-99
					{
						EQ2Bot:MainAssist_Dead
						break
					}
					
					if ${Actor[${MainTankPC}].Health}==-99
					{
						EQ2Bot:MainTank_Dead
						break
					}
				}

				if ${haveaggro} && !${MainTank}
				{
					call Have_Aggro
				}

				call Combat_Routine ${tempvar}
				
				if !${Me.AutoAttackOn} && ${AutoMelee}
				{
					EQ2Execute /toggleautoattack
				}
				
				
				if ${AutoMelee} && !${MainTank}
				{
					;check valid rear position
					if (${Math.Calc[${Target.Heading}-${Me.Heading}]}>-25 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}<25) || (${Math.Calc[${Target.Heading}-${Me.Heading}]}>335 || ${Math.Calc[${Target.Heading}-${Me.Heading}]}<-335
					{
						break
					}
					;check right flank
					elseif (${Math.Calc[${Target.Heading}-${Me.Heading}]}>65 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}<145) || (${Math.Calc[${Target.Heading}-${Me.Heading}]}<-215 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}>-295)
					{
						break
					}
					;check left flank
					elseif (${Math.Calc[${Target.Heading}-${Me.Heading}]}<-65 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}>-145) || (${Math.Calc[${Target.Heading}-${Me.Heading}]}>215 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}<295)
					{
						break
					}
					elseif ${Target.Target.ID}!=${Me.ID}
					{
						call CheckPosition 1 1
					}
				}
				
				if ${Me.ToActor.Power}<85 && ${Me.ToActor.Health}>80 && ${Me.Inventory[ExactName,ManaStone](exists)} && ${usemanastone}
				{
					if ${Math.Calc[${Time.Timestamp}-${mstimer}]}>70
					{
						Me.Inventory[ExactName,ManaStone]:Use
						mstimer:Set[${Time.Timestamp}]
					}
				}

				if (${Actor[${KillTarget}].Health}<1) && !${MainTank}
				{
					break
				}
				
				if (${Target.Health}<1 && ${MainTank})
				{
					break
				}
				
				if ${AutoSwitch} && !${MainTank} && ${Target.Health}>30 && (${Actor[${MainAssist}].Target.Type.Equal[NPC]} || ${Actor[${MainAssist}].Target.Type.Equal[NamedNPC]}) && ${Actor[${MainAssist}].Target.InCombatMode}
				{
					KillTarget:Set[${Actor[${MainAssist}].Target.ID}]
					target ${KillTarget}
					call ProcessTriggers
				}


			}
			while ${tempvar:Inc}<=40

			if !${CurrentTask}
			{
				Script:End
			}

			if (${Actor[${KillTarget}].Health}<1 && !${MainTank}) || (${Target.Health}<1 && ${MainTank} && ${Actor[${KillTarget}].Type.Equal[NPC]} || ${Actor[${KillTarget}].Type.Equal[NamedNPC]})
			{
				break
			}

			call ProcessTriggers
		}
		while (${Actor[${KillTarget}](exists)} && !${MainTank}) || (${Target(exists)} && ${MainTank})

		disablebehind:Set[FALSE]
		disablefront:Set[FALSE]

		if !${MainTank}
		{
			if ${Mob.Detect}
			{
				wait 50 ${Actor[${MainAssist}].Target(exists)}
			}

			if ${Actor[${MainAssist}].Target(exists)}
			{
				KillTarget:Set[${Actor[${MainAssist}].Target.ID}]
				continue
			}
			else
			{
				break
			}
		}

		if ${AutoPull} || ${MainTank}
		{
			checkadds:Set[TRUE]

			call Pull any
			if ${engagetarget}
			{
				continue
			}
		}
	}
	while ${Me.InCombat}

	avoidhate:Set[FALSE]
	checkadds:Set[FALSE]

	tempvar:Set[1]
	do
	{
		call Post_Combat_Routine ${tempvar}
	}
	while ${tempvar:Inc}<=20

	if ${Me.AutoAttackOn}
	{
		EQ2Execute /toggleautoattack
	}

	if ${AutoLoot}
	{
		do
		{
			if ${Mob.Detect}
			{
				break
			}

			if ${Me.ToActor.Health}>=90
			{
				call CheckLoot
				break
			}

			if ${PathType}==4 && ${MainTank}
			{
				call ScanAdds
			}

			if (${Following} && ${Actor[${MainAssist}].Distance}>15) || ${Me.ToActor.Health}>90
			{
				break
			}

			call ProcessTriggers
		}
		while 1
	}

	if ${PathType}==1
	{
		if ${Math.Distance[${Me.X},${Me.Z},${HomeX},${HomeZ}]}>4
		{
			movinghome:Set[TRUE]
			wait ${Math.Rand[50]}
			call FastMove ${HomeX} ${HomeZ} 4
			face ${Math.Rand[45]:Inc[315]}
		}
	}

	if ${Following}
	{
		FollowTask:Set[1]
		wait 20
	}

	if ${MainAssist.NotEqual[${OriginalMA}]} && !${MainTank}
	{
		EQ2Bot:MainAssist_Dead
	}

	if ${MainTankPC.NotEqual[${OriginalMT}]} && !${MainTank}
	{
		EQ2Bot:MainTank_Dead
	}
	if ${PathType}==4
	{
		if ${Math.Distance[${Me.X},${Me.Z},${HomeX},${HomeZ}]}>${ScanRange}
		{
			face ${HomeX} ${HomeZ}
			wait 10

			tempvar:Set[${Math.Rand[30]:Dec[15]}]
			WPX:Set[${Math.Calc[${tempvar}*${Math.Cos[${Me.Heading}]}-20*${Math.Sin[${Me.Heading}]}+${Me.X}]}]
			WPZ:Set[${Math.Calc[-20*${Math.Cos[${Me.Heading}]}+${tempvar}*${Math.Sin[${Me.Heading}]}+${Me.Z}]}]

			call FastMove ${WPX} ${WPZ} 2
		}
	}
}

function GetBehind()
{
	variable float X
	variable float Z

	X:Set[${Math.Calc[-4*${Math.Sin[-${Target.Heading}]}+${Target.X}]}]
	Z:Set[${Math.Calc[4*${Math.Cos[-${Target.Heading}]}+${Target.Z}]}]

	call FastMove ${X} ${Z} 2
	if ${Return.Equal[STUCK]}
	{
		disablebehind:Set[TRUE]
		call FastMove ${Target.X} ${Target.Z} 3
	}

	if ${Target(exists)} && (${Target.ID}!=${Me.ID})
	{
		face ${Target.X} ${Target.Z}
	}

}

function GetToFlank(int extended)
{
	variable float X
	variable float Z
	variable int tempdir

	if ${direction}
	{
		tempdir:Set[-3]
		if ${extended}
		{
			tempdir:Dec[3]
		}
	}
	else
	{
		tempdir:Set[3]
		if ${extended}
		{
			tempdir:Inc[3]
		}
	}

	X:Set[${Math.Calc[${tempdir}*${Math.Cos[-${Target.Heading}]}+${Target.X}]}]
	Z:Set[${Math.Calc[${tempdir}*${Math.Sin[-${Target.Heading}]}+${Target.Z}]}]

	call FastMove ${X} ${Z} 1
	if ${Return.Equal[STUCK]}
	{
		disablebehind:Set[TRUE]
		call FastMove ${Target.X} ${Target.Z} 3
	}

	if ${Target(exists)} && (${Target.ID}!=${Me.ID})
	{
		face ${Target.X} ${Target.Z}
	}
}

function GetinFront()
{
	variable float X
	variable float Z

	X:Set[${Math.Calc[-3*${Math.Sin[${Target.Heading}]}+${Target.X}]}]
	Z:Set[${Math.Calc[-3*${Math.Cos[${Target.Heading}]}+${Target.Z}]}]

	call FastMove ${X} ${Z} 3
	if ${Return.Equal[STUCK]}
	{
		disablefront:Set[TRUE]
		call FastMove ${Target.X} ${Target.Z} 3
	}

	if ${Target(exists)} && (${Target.ID}!=${Me.ID})
	{
		face ${Target.X} ${Target.Z}
	}

	wait 4
}


function CheckPosition(int rangetype, int position)
{
	; rangetype (1=close, 2=max range, 3=bow shooting)
	; position (0=anywhere, 1=behind, 2=front, 3=flank)

	variable float minrange
	variable float maxrange

	if !${Target(exists)}
	{
		return
	}

	switch ${rangetype}
	{
		case NULL
		case 0
			if ${AutoMelee}
			{
				minrange:Set[0]
				maxrange:Set[4]
			}
			else
			{
				minrange:Set[0]
				maxrange:Set[35]
			}
			break
		case 1
			minrange:Set[1]
			maxrange:Set[4.5]
			break
		case 2
			if ${AutoMelee}
			{
				minrange:Set[0]
				maxrange:Set[4]
			}
			else
			{
				minrange:Set[0]
				maxrange:Set[35]
			}
			break
		case 3
			minrange:Set[5.5]
			if ${Me.Equipment[Ranged].Type.Equal[Weapon]}
			{
				
				maxrange:Set[${Me.Equipment[Ranged].Range}]
			}
			else
			{
				maxrange:Set[35]
			}
			break
	}

	if ${Target.Target.ID}==${Me.ID} && ${AutoMelee}
	{
		minrange:Set[0]
		maxrange:Set[4]
	}

	if ${haveaggro}
	{
		position:Set[2]
	}

	if ${disablebehind} && (${position}==1 || ${position}==3)
	{
		position:Set[0]
	}

	if !${MainTank}
	{
		if ${Math.Distance[${Actor[${MainAssist}].X},${Actor[${MainAssist}].Z},${Target.X},${Target.Z}]}>8 && !${Following}
		{
			return
		}
	}
	elseif ${PathType}==2
	{
		if ${Math.Distance[${Me.X},${Me.Z},${HomeX},${HomeZ}]}<8 && ${Me.InCombat} && !${lostaggro} && ${Target.Distance}>10
		{
			return
		}

		if ${Math.Distance[${Me.X},${Me.Z},${HomeX},${HomeZ}]}>5 && ${Math.Distance[${Me.X},${Me.Z},${HomeX},${HomeZ}]}<10 && ${Me.InCombat} && !${lostaggro}
		{
			call FastMove ${HomeX} ${HomeZ} 3
			return
		}
	}

	if ${Target.Distance}>${maxrange} && ${Target.Distance}<35 && ${PathType}!=2 && !${isstuck}
	{
		if ${Target(exists)} && (${Me.ID}!=${Target.ID})
		{
			face ${Target.X} ${Target.Z}
		}
		
		call FastMove ${Target.X} ${Target.Z} ${maxrange}

	}

	if ${Target.Distance}<${minrange} && ${Target(exists)} && (${Me.ID}!=${Target.ID}) && (${rangetype}==1 || ${rangetype}==3)
	{
		movetimer:Set[${Time.Timestamp}]
		press -hold ${backward}
		do
		{
			if ${Target(exists)} && (${Me.ID}!=${Target.ID})
			{
				face ${Target.X} ${Target.Z}
			}

			if ${Math.Calc[${Time.Timestamp}-${movetimer}]}>2
			{
				isstuck:Set[TRUE]
				break
			}
		}
		while ${Target.Distance}<${minrange} && ${Target(exists)}

		press -release ${backward}
		wait 20 !${Me.IsMoving}
	}

	if ${AutoMelee} && ${Target.Distance}>4.5 && (${Me.ID}!=${Target.ID})
	{
		call FastMove ${Target.X} ${Target.Z} 3

		if ${Target(exists)} && (${Me.ID}!=${Target.ID})
		{
			face ${Target.X} ${Target.Z}
		}		
	}

	if ${position}
	{
		switch ${position}
		{
			case 1
				; Behind arc is 60 degree arc. Using 50 degree arc to allow for error
				if (${Math.Calc[${Target.Heading}-${Me.Heading}]}>-25 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}<25) || (${Math.Calc[${Target.Heading}-${Me.Heading}]}>335 || ${Math.Calc[${Target.Heading}-${Me.Heading}]}<-335
				{
					return
				}
				else
				{
					call GetBehind
				}
				break
			case 2
				
				; Frontal Arc is 120 degree arc. Using 110 to allow for error
				if (${Math.Calc[${Target.Heading}-${Me.Heading}]}>125 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}<235) || (${Math.Calc[${Target.Heading}-${Me.Heading}]}>-235 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}<-125)
				{
					return
				}
				else
				{
					call GetinFront
				}
				break
			case 3
				; Using 80 degree flank arc between front and rear arcs with 5 degree error on front and back of the arc
				;check if we are on the left flank
				if (${Math.Calc[${Target.Heading}-${Me.Heading}]}<-65 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}>-145) || (${Math.Calc[${Target.Heading}-${Me.Heading}]}>215 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}<295)
				{
					return
				}
				
				;check if we are at the right flank
				if (${Math.Calc[${Target.Heading}-${Me.Heading}]}>65 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}<145) || (${Math.Calc[${Target.Heading}-${Me.Heading}]}<-215 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}>-295)
				{
					return
				}
				
				;note parameter for GetToflank is null for right, 1 for left
				
				;check if we are on the left side of the mob, if so move to the left flank 
				if ${Math.Calc[${Target.Heading}-${Me.Heading}]}>-180 && ${Math.Calc[${Target.Heading}-${Me.Heading}]}<0
				{
					call GetToFlank 1
				}
				else
				{
					; we must be on the right side of the mob so move to the right flank
					call GetToFlank
				}
				break				
			case default
				break
		}
	}
}

function CheckCondition(string xType, int xvar1, int xvar2)
{
	switch ${xType}
	{
		case MobHealth
			if ${Target.Health}>=${xvar1} && ${Target.Health}<=${xvar2}
			{
				return "OK"
			}
			else
			{
				return "FAIL"
			}
			break

		case Power
			if ${Me.ToActor.Power}>=${xvar1} && ${Me.ToActor.Power}<=${xvar2}
			{
				return "OK"
			}
			else
			{
				return "FAIL"
			}
			break
	}
}

function Pull(string npcclass)
{
	variable int tcount=2
	variable bool chktarget
	variable int tempvar
	variable bool aggrogrp=FALSE

	engagetarget:Set[FALSE]

	if !${Actor[NPC,range,${ScanRange}](exists)} && !(${Actor[NamedNPC,range,${ScanRange}](exists)} && !${IgnoreNamed})
	{
		return
	}

	EQ2:CreateCustomActorArray[byDist,${ScanRange}]
	do
	{
		chktarget:Set[FALSE]
		if ${Mob.ValidActor[${CustomActor[${tcount}].ID}]}
		{
			if ${Mob.AggroGroup[${CustomActor[${tcount}].ID}]}
			{
				aggrogrp:Set[TRUE]
			}

			if !${CustomActor[${tcount}].IsAggro}
			{

				if !${aggrogrp} && ${CustomActor[${tcount}].Target.ID}!=${Me.ID} && !${Me.InCombat} && (${Me.ToActor.Power}<75 || ${Me.ToActor.Health}<90) && !${CustomActor[${tcount}].InCombatMode}
				{
					continue
				}

				if !${aggrogrp} && ${CustomActor[${tcount}].Target.ID}!=${Me.ID} && ${Me.InCombat} && !${CustomActor[${tcount}].InCombatMode}
				{
					continue
				}

				if !${aggrogrp} && ${CustomActor[${tcount}].Target.ID}!=${Me.ID} && !${PullNonAggro}
				{
					continue
				}
			}

			if ${checkadds} && !${aggrogrp} && ${CustomActor[${tcount}].Target.ID}!=${Me.ID}
			{
				continue
			}

			switch ${CustomActor[${tcount}].Class}
			{			
				case templar
				case inquisitor
				case fury
				case warden
				case defiler
				case mystic
					if ${npcclass.Equal[priest]} || ${npcclass.Equal[any]}
					{
						chktarget:Set[TRUE]
					}
					break

				case coercer
				case illusionist
				case warlock
				case wizard
				case conjuror
				case necromancer
					if ${npcclass.Equal[mage]} || ${npcclass.Equal[any]}
					{
						chktarget:Set[TRUE]
					}
					break

				Default
					if ${npcclass.Equal[any]}
					{
						chktarget:Set[TRUE]
					}
					break
			}

			if ${chktarget}
			{
				target ${CustomActor[${tcount}].ID}

				wait 10 ${CustomActor[${tcount}].ID}==${Target.ID}
				wait 10 ${Me.TargetLOS}

				;echo check if in range
				if ((${PathType}==2 || ${PathType}==3 && ${pulling}) || ${PathType}==4) && ${Target.Distance}>${PullRange}
				{
					;echo Move to target Range!
					call FastMove ${Target.X} ${Target.Z} ${PullRange}
				}
				
				if ${Pathtype}==1 && ${Target.Distance}>${PullRange} $$ ${Target.Distance}<35
				{
					;echo Move to target Range!
					call FastMove ${Target.X} ${Target.Z} ${PullRange}
				}
				
				if ${Me.IsMoving}
				{
					press -release ${forward}
					wait 20 !${Me.IsMoving}
				}

				; Use pull spell
				if ${PullWithBow} && ${Target.Distance}>6
				{
					; Use Bow to pull
					EQ2Execute /togglerangedattack
					wait 50 ${CustomActor[${tcount}].InCombatMode}
					if ${CustomActor[${tcount}].InCombatMode}
					{
						KillTarget:Set[${Target.ID}]
						if ${Target(exists)} && !${pulling} && (${Me.ID}!=${Target.ID})
						{
							face ${Target.X} ${Target.Z}
						}
						engagetarget:Set[TRUE]
					}
					if ${Me.InCombat}
					{
						EQ2Execute /togglerangedattack
					}
					break
				}
				else
				{
					call CastSpell "${PullSpell}"
				}

				if (${Return.Equal[CANTSEETARGET]} || ${Return.Equal[TOOFARAWAY]}) && ${pulling} && !${Me.InCombat} && !${CustomActor[${tcount}].InCombatMode}
				{
					EQ2Execute /target_none
				}
				else 
				{
					if ${Return.Equal[TOOFARAWAY]} && ${Math.Distance[${Me.X},${Me.Z},${HomeX},${HomeZ}]}<8 && ${PathType}==2
					{
						call FastMove ${Target.X} ${Target.Z} 3
					}
					elseif ${Return.Equal[CANTSEETARGET]} || ${Return.Equal[TOOFARAWAY]}
					{
						aggrogrp:Set[FALSE]
						if ${Me.GroupCount}>1
						{
							tempvar:Set[1]
							do
							{
								if ${Target.Target.ID}==${Me.Group[${tempvar}].ID} && ${Me.Group[${tempvar}](exists)}
								{
									aggrogrp:Set[TRUE]
									break
								}
							}
							while ${tempvar:Inc}<${Me.GroupCount}
						}

						if !${aggrogrp} && ${Target.Target.ID}!=${Me.ID}
						{
							if ${PathType}==4
							{
								if ${Return.Equal[CANTSEETARGET]}
								{
									EQ2Execute /target_none
									continue
								}

								if ${AutoMelee}
								{
									call FastMove ${Target.X} ${Target.Z} 10
								}
								else
								{
									call FastMove ${Target.X} ${Target.Z} 20
								}

								if ${Return.Equal[STUCK]}
								{
									EQ2Execute /target_none
									continue
								}
							}
							else
							{
								continue
							}
						}

						if ${PathType}==4 && ${Target.Distance}>15
						{
							if ${AutoMelee}
							{
								call FastMove ${Target.X} ${Target.Z} 4
							}
							else
							{
								call FastMove ${Target.X} ${Target.Z} 10
							}
							if ${Return.Equal[STUCK]}
							{
								EQ2Execute /target_none
								continue
							}
						}
					}

					if ${Target.Distance}>10 && !${pulling} && ${PathType}!=2
					{
						if ${AutoMelee}
						{
							call FastMove ${Target.X} ${Target.Z} 1
						}
						elseif ${Target.Distance}>20
						{
							call FastMove ${Target.X} ${Target.Z} 20
						}

						if ${Return.Equal[STUCK]}
						{
							EQ2Execute /target_none
							continue
						}
					}

					KillTarget:Set[${Target.ID}]
					if ${Target(exists)} && !${pulling} && (${Me.ID}!=${Target.ID})
					{
						face ${Target.X} ${Target.Z}
					}
					engagetarget:Set[TRUE]
					break
				}
			}
		}
	}
	while ${tcount:Inc}<=${EQ2.CustomActorArraySize}
	FlushQueued CantSeeTarget
}

function CheckLoot()
{
	variable int tcount=2
	variable int tmptimer

	islooting:Set[TRUE]
	wait 10
	EQ2:CreateCustomActorArray[byDist,15]

	do
	{
		if ${CustomActor[${tcount}].Type.Equal[chest]}
		{
			EQ2Echo Looting ${CustomActor[${tcount}].Name}
			call FastMove ${CustomActor[${tcount}].X} ${CustomActor[${tcount}].Z} 2
			switch ${Me.Class}
			{
				case dirge
				case troubador
				case swashbuckler
				case brigand
				case ranger
				case assassin
					EQ2Execute "/apply_verb ${CustomActor[${tcount}].ID} disarm"
					wait 20
					break
				case default
					break
			}
			Actor[Chest]:DoubleClick
			shwlootwdw:Set[FALSE]
			tmptimer:Set[${Time.Timestamp}]
			do
			{ 
				call LootWdw
				call ProcessTriggers
				WaitFor ${shwlootwdw} 5
				if ${Math.Calc[${Time.Timestamp}-${tmptimer}]}>2
				{
					break
				}
			}
			while !${shwlootwdw}
			wait 4
			press esc
		}
		else
		{
			if ${CustomActor[${tcount}].Type.Equal[Corpse]}
			{
				EQ2Echo Looting ${Actor[corpse].Name}
				call FastMove ${CustomActor[${tcount}].X} ${CustomActor[${tcount}].Z} 2
				Actor[corpse]:DoubleClick
				shwlootwdw:Set[FALSE]
				tmptimer:Set[${Time.Timestamp}]
				do
				{
					call LootWdw
					call ProcessTriggers
					WaitFor ${shwlootwdw} 5
					if ${Math.Calc[${Time.Timestamp}-${tmptimer}]}>2
					{
						break
					}
				}
				while !${shwlootwdw}
				wait 4
				press esc
			}
		}

		if !${CurrentTask}
		{
			Script:End
		}

		if ${CustomActor[${tcount}].IsAggro} || ${Me.InCombat}
		{
			return
		}
	}
	while ${tcount:Inc}<=${EQ2.CustomActorArraySize}
	islooting:Set[FALSE]
}

function FastMove(float X, float Z, int range)
{
	variable float xDist
	variable float SavDist=${Math.Distance[${Me.X},${Me.Z},${X},${Z}]}
	variable int xTimer

	if !${Target(exists)} && !${islooting} && !${movingtowp} && !${movinghome} && ${Me.InCombat}
	{
		return "TARGETDEAD"
	}

	if !${X} || !${Z}
	{
		return "INVALIDLOC"
	}

	if ${Math.Distance[${Me.X},${Me.Z},${X},${Z}]}>30 && !${Following} && ${PathType}!=4
	{
		return "INVALIDLOC"
	}
	elseif ${Math.Distance[${Me.X},${Me.Z},${X},${Z}]}>50 && ${PathType}!=4
	{
		return "INVALIDLOC"
	}

	face ${X} ${Z}

	if !${pulling}
	{
		press -hold ${forward}
	}

	xTimer:Set[${Script.RunningTime}]

	do
	{
		xDist:Set[${Math.Distance[${Me.X},${Me.Z},${X},${Z}]}]

		if ${Math.Calc[${SavDist}-${xDist}]}<0.8
		{
			if (${Script.RunningTime}-${xTimer})>500
			{
				isstuck:Set[TRUE]
				if !${pulling}
				{
					press -release ${forward}
					wait 20 !${Me.IsMoving}
				}
				return "STUCK"
			}
		}
		else
		{
			xTimer:Set[${Script.RunningTime}]
			SavDist:Set[${Math.Distance[${Me.X},${Me.Z},${X},${Z}]}]
		}

		face ${X} ${Z}
	}
	while ${Math.Distance[${Me.X},${Me.Z},${X},${Z}]}>${range}

	if !${pulling}
	{
		press -release ${forward}
		wait 20 !${Me.IsMoving}
	}

	return "SUCCESS"
}

function MovetoWP(string destination)
{
	NavPath:Clear
	pathindex:Set[1]
	movingtowp:Set[TRUE]
	stuckcnt:Set[0]
	
	NearestPoint:Set[${Navigation.World[${World}].NearestPoint[${Me.X},${Me.Y},${Me.Z}]}]

	if ${PathType}==3
	{
		if ${NearestPoint.Equal[Finish]}
		{
			destination:Set[Start]
			DCDirection:Set[Start]
		}
		elseif ${NearestPoint.Equal[Start]}
		{
			destination:Set[Finish]
			DCDirection:Set[Finish]
		}
	}

	NavPath "${World}" "${NearestPoint}" "${destination}"

	if ${NavPath.Points}>0
	{
		if (${pulling} || ${PathType}==3) && !${Me.IsMoving}
		{
			face ${NavPath.Point[1].X} ${NavPath.Point[1].Z}
			wait 5
			press -hold ${forward}
			PositionHeading:Set[${Me.Heading}]
		}

		do
		{
			; Move to next Waypoint
			WPX:Set[${NavPath.Point[${pathindex}].X}]
			WPZ:Set[${NavPath.Point[${pathindex}].Z}]

			call FastMove ${WPX} ${WPZ} 3

			if ${Return.Equal[STUCK]}
			{
				; can sort out later what to do with stuck problems
				stuckcnt:Inc

				if ${stuckcnt}>10 && ${Me.IsMoving}
				{
					return "STUCK"
				}

				if (${pulling} || ${PathType}==3) && !${Me.IsMoving}
				{
					press -hold ${forward}
				}
			}

			if ${PathType}==3
			{
				call Pull any
				if ${engagetarget}
				{
					if !${Mob.Detect}
					{
						engagetarget:Set[FALSE]
					}
					else
					{
						if ${Target(exists)} && (${Me.ID}!=${Target.ID})
						{
							face ${Target.X} ${Target.Z}
						}
					}
					pulling:Set[FALSE]
					return
				}
			}
			elseif ${pulling} && ${destination.NotEqual[Start]}
			{
				call Pull any
				if ${engagetarget}
				{
					if !${Mob.Detect}
					{
						engagetarget:Set[FALSE]
					}
					else
					{
						call MovetoWP "Start"
						if !${Mob.Detect}
						{
							engagetarget:Set[FALSE]
						}
						else
						{
							if ${Target(exists)} && (${Me.ID}!=${Target.ID})
							{
								face ${Target.X} ${Target.Z}
							}
						}
					}
					pulling:Set[FALSE]
					return
				}

				if ${pathindex}==${NavPath.Points}
				{
					if ${TotalPull}==1
					{
						call MovetoWP "Start"
						wait 10

						if ${Target(exists)} && (${Me.ID}!=${Target.ID})
						{
							face ${Target.X} ${Target.Z}
						}
						pulling:Set[FALSE]
						return
					}

					if !${pathdirection}
					{
						if ${CurrentPull}>=${TotalPull}
						{
							pathdirection:Set[!${pathdirection}]
							CurrentPull:Dec
						}
						else
						{
							CurrentPull:Inc
						}
					}
					else
					{
						if ${CurrentPull}==1
						{
							pathdirection:Set[!${pathdirection}]
							CurrentPull:Inc
						}
						else
						{
							CurrentPull:Dec
						}
					}

					call MovetoWP "Pull ${CurrentPull}"
					return
				}
			}
		}		
		while ${pathindex:Inc}<=${NavPath.Points}

		if (${pulling} || ${PathType}==3) && ${Me.IsMoving}
		{
			press -release ${forward}
			wait 20 !${Me.IsMoving}
		}
	}
	movingtowp:Set[FALSE]
}

function MovetoMaster()
{
	variable string MasterPoint
	variable int tmpdev

	NavPath:Clear
	pathindex:Set[1]
	stuckcnt:Set[0]

	tmpdev:Set[${Math.Rand[${Math.Calc[${Deviation}*2+1]}]:Dec[${Deviation}]}]	
	MasterPoint:Set[${Navigation.World[${World}].NearestPoint[${Actor[${MainAssist}].X},${Actor[${MainAssist}].Y},${Actor[${MainAssist}].Z}]}
	NearestPoint:Set[${Navigation.World[${World}].NearestPoint[${Me.X},${Me.Y},${Me.Z}]}]

	NavPath "${World}" "${NearestPoint}" "${MasterPoint}"

	if ${NavPath.Points}>0
	{
		if !${Me.IsMoving}
		{
			press -hold ${forward}
		}

		do
		{
			; Move to next Waypoint
			WPX:Set[${Math.Calc[${tmpdev}*${Math.Cos[-${Me.Heading}]}+${NavPath.Point[${pathindex}].X}]
			WPZ:Set[${Math.Calc[${tmpdev}*${Math.Sin[-${Me.Heading}]}+${NavPath.Point[${pathindex}].Z}]


			call FastMove ${WPX} ${WPZ} 3

			if ${Return.Equal[STUCK]}
			{
				; can sort out later what to do with stuck problems
				stuckcnt:Inc

				if ${stuckcnt}>10 && ${Me.IsMoving}
				{
					return "STUCK"
				}

				if !${Me.IsMoving}
				{
					press -hold ${forward}
				}
			}
		}		
		while ${pathindex:Inc}<=${NavPath.Points}

		if ${Me.IsMoving}
		{
			press -release ${forward}
			wait 20 !${Me.IsMoving}
		}
	}
}

function ProcessTriggers() 
{
	if "${QueuedCommands}"
	{
		do 
		{
			ExecuteQueued 
		}
		while "${QueuedCommands}"
	}
}

function IamDead(string Line)
{
	variable int deathtimer=${Time.Timestamp}
	KillTarget:Set[]
	if ${Me.GroupCount}==1
	{
		EQ2Execute "select_junction 0"
		do
		{
			waitframe
		}
		while ${EQ2.Zoning}

		wait 3000
		Exit
	}
	else
	{
		do
		{
			if ${Math.Calc[${Time.Timestamp}-${deathtimer}]}>5000
			{
				Exit
			}

			if ${EQ2UIPage[Choice,RoundedGrouper].Child[button,Choice.Choice1](exists)}
			{
				EQ2UIPage[Choice,RoundedGrouper].Child[button,Choice.Choice1]:LeftClick
			}
		}
		while ${Me.ToActor.Health}<1
	}
}

function LoreItem(string Line)
{
	if ${EQ2UIPage[Choice,RoundedGrouper].Child[button,Choice.Choice2](exists)} && ${LootAll}
	{
		EQ2UIPage[Choice,RoundedGrouper].Child[button,Choice.Choice2]:LeftClick
	}
	press esc
	press esc
}

function CheckMTAggro()
{
	variable int tcount=2
	variable int tempvar
	variable int newtarget

	; If PathType is 2 make sure we are not to far away from home point first
	if ${PathType}==2 && ${Math.Distance[${Me.X},${Me.Z},${HomeX},${HomeZ}]}>8
	{
		call FastMove ${HomeX} ${HomeZ} 4
		if ${Target(exists)} && (${Me.ID}!=${Target.ID})
		{
			face ${Target.X} ${Target.Z}
		}
	}

	lostaggro:Set[FALSE]

	if !${Actor[NPC,range,15](exists)} && !(${Actor[NamedNPC,range,15](exists)} && !${IgnoreNamed})
	{
		return "NOAGGRO"
	}

	newtarget:Set[${Target.ID}]

	EQ2:CreateCustomActorArray[byDist,15]
	do
	{
		if ${Mob.ValidActor[${CustomActor[${tcount}].ID}]} && ${CustomActor[${tcount}].InCombatMode}
		{
			if ${Math.Calc[${CustomActor[${tcount}].Health}+1]}<${Actor[${newtarget}].Health} && ${Actor[${newtarget}](exists)}
			{
				newtarget:Set[${CustomActor[${tcount}].ID}]
			}

			if ${CustomActor[${tcount}].Target.ID}!=${Me.ID}
			{
				if !${Mob.AggroGroup[${CustomActor[${tcount}].ID}]}
				{
					continue
				}

				KillTarget:Set[${CustomActor[${tcount}].ID}]
				target ${KillTarget}
				wait 10 ${Target.ID}==${KillTarget}

				if ${Target(exists)} && (${Me.ID}!=${Target.ID})
				{
					face ${Target.X} ${Target.Z} 
				}

				call Lost_Aggro ${KillTarget}
				lostaggro:Set[TRUE]
				return
			}
		}
	}
	while ${tcount:Inc}<=${EQ2.CustomActorArraySize}

	if ${Actor[${newtarget}](exists)}
	{
		KillTarget:Set[${newtarget}]
		target ${KillTarget}

		wait 10 ${Target.ID}==${KillTarget}

		if ${Target(exists)} && (${Me.ID}!=${Target.ID})
		{
			face ${Target.X} ${Target.Z}
		}
	}	
}

function ScanAdds()
{
	variable int tcount=2
	variable float X
	variable float Z

	EQ2:CreateCustomActorArray[byDist,20]
	do
	{
		; Check if there is an add approaching us and move away from it accordingly
		if (${CustomActor[${tcount}].Type.Equal[NPC]} || ${CustomActor[${tcount}].Type.Equal[NamedNPC]}) && ${Actor[${CustomActor[${tcount}].ID}](exists)} && !${CustomActor[${tcount}].IsLocked} && ${Math.Calc[${Me.Y}+10]}>=${CustomActor[${tcount}].Y} && ${Math.Calc[${Me.Y}-10]}<=${CustomActor[${tcount}].Y} && !${CustomActor[${tcount}].InCombatMode} && ${CustomActor[${tcount}].IsAggro}
		{
			if ${CustomActor[${tcount}].Target.ID}!=${Actor[MyPet].ID} || ${CustomActor[${tcount}].Target.ID}!=${Me.ID}
			{
				X:Set[${Math.Calc[-8*${Math.Sin[-${CustomActor[${tcount}].HeadingTo}]}+${Me.X}]}]
				Z:Set[${Math.Calc[8*${Math.Cos[-${CustomActor[${tcount}].HeadingTo}]}+${Me.Z}]}]
				call FastMove ${X} ${Z}  2
				if ${Return.Equal[STUCK]}
				{
					; Need to do something here? decide later
				}
				return
			}
		}
	}
	while ${tcount:Inc}<=${EQ2.CustomActorArraySize}
}

function LootWdw(string Line)
{
	if ${LootAll}
	{
		wait 5
		EQ2UIPage[Inventory,Loot].Child[button,Loot.button RequestAll]:LeftClick
		wait 5
		if ${EQ2UIPage[Choice,RoundedGrouper].Child[button,Choice.Choice1](exists)}
		{
			EQ2UIPage[Choice,RoundedGrouper].Child[button,Choice.Choice1]:LeftClick
		}
	}
}

function CantSeeTarget(string Line)
{
	if (${haveaggro} || ${MainTank}) && ${Me.InCombat}
	{
		if ${Target.Target.ID}==${Me.ID}
		{
			if ${Target(exists)} && (${Me.ID}!=${Target.ID})
			{
				face ${Target.X} ${Target.Z}
			}

			press -hold ${backward}
			wait 5
			press -release ${backward}
			wait 20 !${Me.IsMoving}
			return
		}
	}
}


function BotFollow(string Line, string FollowTarget)
{
	variable string tempTarget

	if ${FollowTarget.Equal[me]}
	{
		tempTarget:Set[${MainAssist}]
	}
	else
	{
		tempTarget:Set[${FollowTarget}]
	}

	if !${Actor[${tempTarget},radius,30].ID}
	{
		EQ2Echo ${tempTarget} is out of range or does not exist.
	}
	else
	{
		if ${Script[follow](exists)}
		{
			Script[Follow].Variable[ftarget]:Set[${tempTarget}]
			Script[Follow]:QueueCommand[call ResetPoints]
		}
		if ${tempTarget.Length} && !${Script[follow](exists)}
		{
			run follow "${tempTarget}" 1
			Following:Set[TRUE]
		}
	}
}
 
function BotStop()
{
	FollowTask:Set[0]
}
 
function BotAbort()
{
	Script:End
}
 
function BotCommand(string line, string doCommand)
{
	EQ2Execute /${doCommand}
}
 
function BotTell(string line, string tellSender, string tellMessage)
{
	uplink relay ${MasterSession} "EQ2Echo ${tellSender} tells ${Me.Name}, ${tellMessage}"
}
 
function BotAutoMeleeOn()
{
	AutoMelee:Set[TRUE]	
}
 
function BotAutoMeleeOff()
{
	AutoMelee:Set[FALSE]

	if ${Me.AutoAttackOn}
	{
		EQ2Execute /toggleautoattack
	}	
}

function BotCastTarget(string line, string Spell, string castTarget)
{
	variable string tempTarget

	if ${castTarget.Equal[me]}
	{
		tempTarget:Set[${MainAssist}]
	}
	else
	{
		tempTarget:Set[${castTarget}]
	}
	target ${tempTarget}
	wait 2
	call CastSpell "${Spell}"
}

function PreReactiveOn()
{
	KeepReactive:Set[1]
}

function PreReactiveOff()
{
	KeepReacitve:Set[0]
}

function StartBot()
{
	variable int tempvar1
	variable int tempvar2

	SettingXML[Scripts/EQ2Bot/Character Config/${Me.Name}.xml].Set[Temporary Settings]:Set["StartXP",${Me.Exp}]:Save
	SettingXML[Scripts/EQ2Bot/Character Config/${Me.Name}.xml].Set[Temporary Settings]:Set["StartTime",${Time.Timestamp}]:Save

	if ${CloseUI}
	{
		ui -unload ${LavishScript.HomeDirectory}/Interface/eq2skin.xml
		ui -unload ${LavishScript.HomeDirectory}/Scripts/EQ2Bot/UI/eq2bot.xml
	}
	else
	{
		UIElement[EQ2 Bot].FindUsableChild[Pathing Frame,frame]:Hide
		UIElement[EQ2 Bot].FindUsableChild[Start EQ2Bot,commandbutton]:Hide
		UIElement[EQ2 Bot].FindUsableChild[Combat Frame,frame]:Show
		UIElement[EQ2 Bot].FindUsableChild[Stop EQ2Bot,commandbutton]:Show
		UIElement[EQ2 Bot].FindUsableChild[Pause EQ2Bot,commandbutton]:Show
	}

	switch ${PathType}
	{
		case 0
			break

		case 1
			HomeX:Set[${Me.X}]
			HomeZ:Set[${Me.Z}]
			break

		case 2
			CurrentPull:Set[1]
			World:Set[${Zone.ShortName}]
			Navigation -reset
			Navigation -load "${mainpath}XML/EQ2Combat_${Zone.ShortName}.xml"

			; Check how many pull spots there are
			tempvar1:Set[1]

			do
			{
				if ${Navigation.World[${Zone.ShortName}].Point[${tempvar1}].Name.Left[4].Equal[Pull]}
				{
					tempvar2:Set[${Navigation.World[${Zone.ShortName}].Point[${tempvar1}].Name.Token[2," "]}]
					if ${TotalPull}<${tempvar2}
					{
						TotalPull:Set[${tempvar2}]
					}
				}
			}
			while ${tempvar1:Inc}<=${Navigation.World[${Zone.ShortName}].LastID}

			call MovetoWP "Start"
			HomeX:Set[${Me.X}]
			HomeZ:Set[${Me.Z}]
			break

		case 3
			World:Set[${Zone.ShortName}]
			Navigation -reset
			Navigation -load "${mainpath}XML/EQ2Combat_${Zone.ShortName}.xml"
			break

		case 4
			HomeX:Set[${Me.X}]
			HomeZ:Set[${Me.Z}]
			MainTank:Set[TRUE]
			break
	}

	; Need to move this so that its set when MainAssist changes.
	OriginalMA:Set[${MainAssist}]
	OriginalMT:Set[${MainTankPC}]
	

	if !${PathType} && ${Following}
	{
		if ${Script[follow](exists)}
		{
			Script[follow]:End
			wait 10
		}
		run follow "${Follow}" ${Deviation} ${Leash}
	}
	else
	{
		Following:Set[FALSE]
	}

	StartBot:Set[TRUE]
}

function PauseBot()
{
	PauseBot:Set[TRUE]
	UIElement[EQ2 Bot].FindUsableChild[Pause EQ2Bot,commandbutton]:Hide
	UIElement[EQ2 Bot].FindUsableChild[Resume EQ2Bot,commandbutton]:Show

	do
	{
		waitframe
		call ProcessTriggers
	}
	while ${PauseBot}
}

function ResumeBot()
{
	PauseBot:Set[FALSE]
	UIElement[EQ2 Bot].FindUsableChild[Resume EQ2Bot,commandbutton]:Hide
	UIElement[EQ2 Bot].FindUsableChild[Pause EQ2Bot,commandbutton]:Show
}

function StopBot()
{
	UIElement[EQ2 Bot].FindUsableChild[Stop EQ2Bot,commandbutton]:Hide
	UIElement[EQ2 Bot].FindUsableChild[Resume EQ2Bot,commandbutton]:Hide
	UIElement[EQ2 Bot].FindUsableChild[Pause EQ2Bot,commandbutton]:Hide
	UIElement[EQ2 Bot].FindUsableChild[Combat Frame,frame]:Hide
	UIElement[EQ2 Bot].FindUsableChild[Pathing Frame,frame]:Show
	UIElement[EQ2 Bot].FindUsableChild[Start EQ2Bot,commandbutton]:Show
}


objectdef ActorCheck
{
	;returns true for valid targets
	member:bool ValidActor(int actorid)
	{
		switch ${Actor[${actorid}].Type}
		{
			case NPC
				break

			case NamedNPC
				if ${IgnoreNamed}
				{
					return FALSE
				}
				break

			case PC
				return FALSE

			Default
				return FALSE
		}

		switch ${Actor[${actorid}].ConColor}
		{
			case Yellow
				if ${IgnoreYellowCon}
				{
					return FALSE
				}
				break

			case White
				if ${IgnoreWhiteCon}
				{
					return FALSE
				}
				break

			case Blue
				if ${IgnoreBlueCon}
				{
					return FALSE
				}
				break

			case Green
				if ${IgnoreGreenCon}
				{
					return FALSE
				}
				break

			case Orange
				if ${IgnoreOrangeCon}
				{
					return FALSE
				}
				break

			case Red
				if ${IgnoreRedCon}
				{
					return FALSE
				}
				break

			case Grey
				if ${IgnoreGreyCon}
				{
					return FALSE
				}
				break

			Default
				return FALSE
		}
		
		;checks if mob is too far above or below us
		if ${Me.Y}+10<${Actor[${actorid}].Y} || ${Me.Y}-10>${Actor[${actorid}].Y}
		{
			return FALSE
		}

		if ${Actor[${actorid}].IsLocked}
		{
			return FALSE
		}

		if ${Actor[${actorid}].IsHeroic} && ${IgnoreHeroic}
		{
			return FALSE
		}

		if ${Actor[${actorid}].IsEpic} && ${IgnoreEpic}
		{
			return FALSE
		}

		if ${Actor[${actorid}](exists)}
		{
			return TRUE
		}
		else
		{
			return FALSE
		}
	}

	; Check if mob is aggro on Raid, group, or pet only, doesn't check agro on Me
	member:bool AggroGroup(int actorid)
	{
		variable int tempvar

		if ${Me.GroupCount}>1
		{
			; Check if mob is aggro on group or pet
			tempvar:Set[1]
			do
			{
				if (${Actor[${actorid}].Target.ID}==${Me.Group[${tempvar}].ID} && ${Me.Group[${tempvar}](exists)}) || ${Actor[${actorid}].Target.ID}==${Me.Group[${tempvar}].PetID}
				{
					return TRUE
				}
			}
			while ${tempvar:Inc}<${Me.GroupCount}

			; Check if mob is aggro on raid or pet
			if ${Me.InRaid}
			{
				tempvar:Set[1]
				do
				{
					if (${Actor[${actorid}].Target.ID}==${Me.Raid[${tempvar}].ID} && ${Me.Raid[${tempvar}](exists)}) || ${Actor[${actorid}].Target.ID}==${Me.Raid[${tempvar}].PetID}
					{
						return TRUE
					}
				}
				while ${tempvar:Inc}<24
			}
		}

		if ${Actor[MyPet](exists)} && ${Actor[${actorid}].Target.ID}==${Actor[MyPet].ID}
		{
			return TRUE
		}
		return FALSE
	}

	;returns count of mobs engaged in combat near you.  Includes mobs not engaged to other pcs/groups
	member:int Count()
	{
		variable int tcount=2
		variable int mobcount

		if !${Actor[NPC,range,15](exists)} && !(${Actor[NamedNPC,range,15](exists)} && !${IgnoreNamed})
		{
			return 0
		}

		EQ2:CreateCustomActorArray[byDist,15]
		do
		{
			if ${This.ValidActor[${CustomActor[${tcount}].ID}]} && ${CustomActor[${tcount}].InCombatMode}
			{
				mobcount:Inc
			}
		}
		while ${tcount:Inc}<=${EQ2.CustomActorArraySize}

		return ${mobcount}
	}

	;returns true if you, group, raidmember, or pets have agro from mob in range
	member:bool Detect()
	{
		variable int tcount=2

		if !${Actor[NPC,range,15](exists)} && !(${Actor[NamedNPC,range,15](exists)} && !${IgnoreNamed})
		{
			return FALSE
		}

		EQ2:CreateCustomActorArray[byDist,15]
		do
		{
			if ${This.ValidActor[${CustomActor[${tcount}].ID}]} && ${CustomActor[${tcount}].InCombatMode}
			{
				if ${CustomActor[${tcount}].Target.ID}==${Me.ID}
				{
					return TRUE
				}

				if ${This.AggroGroup[${CustomActor[${tcount}].ID}]}
				{
					return TRUE
				}
			}
		}
		while ${tcount:Inc}<=${EQ2.CustomActorArraySize}

		return FALSE
	}

	member:bool Target(int targetid)
	{
		if !${Actor[${targetid}].InCombatMode}
		{
			return FALSE
		}

		if ${This.AggroGroup[${targetid}]} || ${Actor[${targetid}].Target.ID}==${Me.ID}
		{
			return TRUE
		}

		return FALSE
	}

	method CheckMYAggro()
	{
		variable int tcount=2
		haveaggro:Set[FALSE]

		if !${Actor[NPC,range,15](exists)} && !(${Actor[NamedNPC,range,15](exists)} && !${IgnoreNamed})
		{
			return
		}

		EQ2:CreateCustomActorArray[byDist,15]
		do
		{
			if ${This.ValidActor[${CustomActor[${tcount}].ID}]} && ${CustomActor[${tcount}].Target.ID}==${Me.ID} && ${CustomActor[${tcount}].InCombatMode}
			{
				haveaggro:Set[TRUE]
				aggroid:Set[${CustomActor[${tcount}].ID}]
				return
			}
		}
		while ${tcount:Inc}<=${EQ2.CustomActorArraySize}
	}
}

objectdef EQ2BotObj
{
	method Init_Character()
	{
		charfile:Set[${mainpath}EQ2Bot/Character Config/${Me.Name}.xml]

		switch ${Me.Archetype}
		{
			case scout
				AutoMelee:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Auto Melee,TRUE]}]
				break

			case fighter
				AutoMelee:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Auto Melee,TRUE]}]
				break

			case priest
				AutoMelee:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Auto Melee,FALSE]}]
				break

			case mage
				AutoMelee:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Auto Melee,FALSE]}]
				break
		}

		MainTank:Set[${SettingXML[${charfile}].Set[General Settings].GetString[I am the Main Tank?,TRUE]}]

		if ${MainTank}
		{
			SettingXML[${charfile}].Set[General Settings]:Set[Who is the Main Assist?,${Me.Name}]:Save
		}

		MainAssist:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Who is the Main Assist?,${Me.Name}]}]
		MainTankPC:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Who is the Main Tank?,${Me.Name}]}]
		AutoSwitch:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Auto Switch Targets when Main Assist Switches?,TRUE]}]
		AutoLoot:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Auto Loot Corpses and open Treasure Chests?,FALSE]}]
		KeepReactive:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Cast or Wait for Reactive pre-combat?,FALSE]}]
		LootAll:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Accept Loot Automatically?,TRUE]}]
		AutoPull:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Auto Pull,FALSE]}]
		PullSpell:Set[${SettingXML[${charfile}].Set[General Settings].GetString[What to use when PULLING?,SPELL]}]
		PullRange:Set[${SettingXML[${charfile}].Set[General Settings].GetString[What RANGE to PULL from?,15]}]
		PullWithBow:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Pull with Bow (Ranged Attack)?,FALSE]}]
		ScanRange:Set[${SettingXML[${charfile}].Set[General Settings].GetString[What RANGE to SCAN for Mobs?,20]}]
		PowerCheck:Set[${SettingXML[${charfile}].Set[General Settings].GetInt[Minimum Power the puller will pull at?,80]}]
		HealthCheck:Set[${SettingXML[${charfile}].Set[General Settings].GetInt[Minimum Health the puller will pull at?,90]}]
		IgnoreEpic:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Ignore Epic Encounters?,TRUE]}]
		IgnoreNamed:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Ignore Named Encounters?,TRUE]}]
		IgnoreHeroic:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Ignore Heroic Encounters?,FALSE]}]
		IgnoreRedCon:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Ignore Red Con Mobs?,TRUE]}]
		IgnoreOrangeCon:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Ignore Orange Con Mobs?,TRUE]}]
		IgnoreYellowCon:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Ignore Yellow Con Mobs?,FALSE]}]
		IgnoreWhiteCon:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Ignore White Con Mobs?,FALSE]}]
		IgnoreBlueCon:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Ignore Blue Con Mobs?,FALSE]}]
		IgnoreGreenCon:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Ignore Green Con Mobs?,FALSE]}]
		IgnoreGreyCon:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Ignore Grey Con Mobs?,TRUE]}]
		PullNonAggro:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Pull Non Aggro Mobs?,TRUE]}]
		AssistHP:Set[${SettingXML[${charfile}].Set[General Settings].GetInt[Assist and Engage in combat at what Health?,96]}]
		Following:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Are we following someone?,FALSE]}]
		Follow:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Who are we following?,${MainAssist}]}]
		Deviation:Set[${SettingXML[${charfile}].Set[General Settings].GetInt[What is our Deviation for following?,1]}]
		Leash:Set[${SettingXML[${charfile}].Set[General Settings].GetInt[What is our Leash Range?,0]}]
		PathType:Set[${SettingXML[${charfile}].Set[General Settings].GetInt[What Path Type (0-4)?,0]}]
		CloseUI:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Close the UI after starting EQ2Bot?,FALSE]}]
		MasterSession:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Master IS Session,Master.is1]}]
		LootConfirm:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Do you want to Loot Lore or No Trade Items?,TRUE]}]
		CheckPriestPower:Set[${SettingXML[${charfile}].Set[General Settings].GetString[Check if Priest has Power in the Group?,TRUE]}]

		if ${PullWithBow}
		{
			if !${Me.Equipment[ammo](exists)} || !${Me.Equipment[ranged](exists)}
			{
				PullWithBow:Set[FALSE]
			}
			else
			{
				PullRange:Set[25]
			}
		}

		SettingXML[${charfile}]:Save
	}

	method Init_Config()
	{
		bind EndBot ${endbot} "Script[EQ2Bot]:End"
		spellfile:Set[${mainpath}EQ2Bot/Spell List/${Me.SubClass}.xml]
		This:CheckSpells[${Me.SubClass}]
	}

	method CheckSpells(string class)
	{
		variable int keycount
		variable string templvl
		variable string tempnme
		variable int tempvar=1
		variable string spellname

		keycount:Set[${SettingXML[${spellfile}].Set[${class}].Keys}]
		do
		{
			tempnme:Set["${SettingXML[${spellfile}].Set[${class}].Key[${tempvar}]}"]

			templvl:Set[${Arg[1,${tempnme}]}]

			if ${templvl}>${Me.Level}
			{
				return
			}

			spellname:Set[${SettingXML[${spellfile}].Set[${class}].GetString["${tempnme}"]}]
			if !${Me.Ability[${spellname}](exists)} && ${spellname.Length}
			{
				echo Are you missing spell: ${spellname}
			}

			SpellType[${Arg[2,${tempnme}]}]:Set[${spellname}]
		}
		while ${tempvar:Inc}<=${keycount}
	}

	method Init_Triggers()
	{

		; General Triggers
		AddTrigger IamDead "@npc@ has killed you."
		AddTrigger LoreItem "@*@You cannot have more than one of any given LORE item."
		AddTrigger LootWdw "LOOTWINDOW::LOOTWINDOW"
		AddTrigger CantSeeTarget "@*@Can't see target@*@"

		; Bot Triggers
		AddTrigger BotCastTarget "cast @Spell@ on @castTarget@"
		AddTrigger BotFollow "follow @followTarget@"
		AddTrigger BotStop "EQ2Bot stop"
		AddTrigger BotAbort "EQ2Bot end"
		AddTrigger BotAbort "It will take about 20 more seconds to prepare your camp."
		AddTrigger BotTell "@tellSender@ tells you,@tellMessage@"
		AddTrigger BotCommand "EQ2Bot /@doCommand@"
		AddTrigger BotAutoMeleeOn "EQ2Bot melee on"
		AddTrigger BotAutoMeleeOff "EQ2Bot melee off"
		AddTrigger PreReactiveOn "prereactive on"
		AddTrigger PreReactiveOff "prereactive off"


	}

	method Init_UI()
	{
		ui -reload "${LavishScript.HomeDirectory}/Interface/eq2skin.xml"
		ui -reload -skin eq2skin "${LavishScript.HomeDirectory}/Scripts/EQ2Bot/UI/eq2bot.xml"
	}

	member:float ConvertAngle(float angle)
	{
		if ${angle}<-180
		{
			direction:Set[TRUE]
			return ${angle:Inc[360]}
		}

		if ${angle}>=-180 && ${angle}<1
		{
			direction:Set[FALSE]
			return ${Math.Abs[${angle}]}
		}

		if ${angle}>180
		{
			direction:Set[FALSE]
			return ${Math.Calc[360-${angle}]}
		}
		else
		{
			direction:Set[TRUE]
		}

		return ${angle}
	}

	member:int ScanWaypoints()
	{
		variable int tempvar
		variable int tcount

		EQ2:CreateCustomActorArray[byDist]

		tempvar:Set[1]
		do
		{
			NavPath:Clear
			pathindex:Set[1]

			NavPath "${World}" "Start" "Pull ${tempvar}"

			if ${NavPath.Points}>0
			{
				do
				{
					WPX:Set[${NavPath.Point[${pathindex}].X}]
					WPY:Set[${NavPath.Point[${pathindex}].Y}]
					WPZ:Set[${NavPath.Point[${pathindex}].Z}]

					tcount:Set[2]
					do
					{
						if ${Math.Distance[${WPX},${WPZ},${CustomActor[${tcount}].X},${CustomActor[${tcount}].Z}]}<${ScanRange}
						{
					 		if ${Mob.ValidActor[${CustomActor[${tcount}].ID}]}
							{
								return ${tempvar}
							}
						}
					}
					while ${tcount:Inc}<=${EQ2.CustomActorArraySize}
				}		
				while ${pathindex:Inc}<=${NavPath.Points}
			}
		}
		while ${tempvar:Inc}<=${TotalPull}

		return 0
	}

	member:int ProtectHealer()
	{
		variable int tempvar=1

		do
		{
			switch ${Me.Group[${tempvar}].Class}
			{
				case priest
				case cleric
				case templar
				case inquisitor
				case druid
				case fury
				case warden
				case shaman
				case defiler
				case mystic
					return ${Me.Group[${tempvar}].ID}
			}
		}
		while ${tempvar:Inc}<${Me.GroupCount}

		return 0
	}

	method MainAssist_Dead()
	{
		if ${Actor[${OriginalMA}].Health}>0 && ${Actor[${OriginalMA}](exists)}
		{
			MainTank:Set[FALSE]
			MainAssist:Set[${OriginalMA}]
			KillTarget:Set[]
			EQ2Echo Switching back to the original MainAssist ${MainAssist}
			return
		}
		MainAssist:Set[${MainTankPC}]
	}
	
	method MainTank_Dead()
	{
		variable int highesthp

		if ${Actor[${OriginalMT}].Health}>0 && ${Actor[${OriginalMT}](exists)}
		{
			MainTank:Set[FALSE]
			MainAssist:Set[${OriginalMT}]
			KillTarget:Set[]
			EQ2Echo Switching back to the original MainAssist ${MainAssist}
			return
		}

		if ${Me.Archetype.Equal[fighter]}
		{
			highesthp:Set[${Me.MaxHealth}]
			MainTank:Set[TRUE]
			MainAssist:Set[${Me.Name}]
		}

		grpcnt:Set[${Me.GroupCount}]
		tempgrp:Set[1]
		do
		{
			switch ${Me.Group[${tempgrp}].Class}
			{
				case berserker
				case guardian
				case bruiser
				case monk
				case paladin
				case shadowknight
					if ${Me.Group[${tempgrp}].MaxHitPoints}>${highesthp}
					{
						highesthp:Set[${Me.Group[${tempgrp}].MaxHitPoints}]
						MainTank:Set[FALSE]
						MainAssist:Set[${Me.Group[${tempgrp}].Name}]
					}
			}
		}
		while ${tempgrp:Inc}<${grpcnt}

		if ${Me.InRaid}
		{
			tempgrp:Set[1]
			do
			{
				switch ${Me.Raid[${tempgrp}].Class}
				{
					case berserker
					case guardian
					case bruiser
					case monk
					case paladin
					case shadowknight
						if ${Me.Raid[${tempgrp}].MaxHitPoints}>${highesthp}
						{
							highesthp:Set[${Me.Raid[${tempgrp}].MaxHitPoints}]
							MainTank:Set[FALSE]
							MainAssist:Set[${Me.Raid[${tempgrp}].Name}]
						}
				}
			}
			while ${tempgrp:Inc}<24
		}

		if ${highesthp}
		{
			EQ2Echo Setting MainAssist to ${MainAssist}
			return
		}

		if ${Me.Archetype.Equal[scout]}
		{
			highesthp:Set[${Me.MaxHealth}]
			MainTank:Set[TRUE]
			MainAssist:Set[${Me.Name}]
		}

		tempgrp:Set[1]
		do
		{
			switch ${Me.Group[${tempgrp}].Class}
			{
				case assassin
				case ranger
				case brigand
				case swashbuckler
				case dirge
				case troubador
					if ${Me.Group[${tempgrp}].MaxHitPoints}>${highesthp}
					{
						highesthp:Set[${Me.Group[${tempgrp}].MaxHitPoints}]
						MainTank:Set[FALSE]
						MainAssist:Set[${Me.Group[${tempgrp}].Name}]
					}
			}
		}
		while ${tempgrp:Inc}<${grpcnt}

		if ${highesthp}
		{
			EQ2Echo Setting MainAssist to ${MainAssist}
			return
		}

		if ${Me.Archetype.Equal[mage]}
		{
			highesthp:Set[${Me.MaxHealth}]
			MainTank:Set[TRUE]
			MainAssist:Set[${Me.Name}]
		}

		tempgrp:Set[1]
		do
		{
			switch ${Me.Group[${tempgrp}].Class}
			{
				case conjuror
				case necromancer
				case warlock
				case wizard
				case coercer
				case illusionist
					if ${Me.Group[${tempgrp}].MaxHitPoints}>${highesthp}
					{
						highesthp:Set[${Me.Group[${tempgrp}].MaxHitPoints}]
						MainTank:Set[FALSE]
						MainAssist:Set[${Me.Group[${tempgrp}].Name}]
					}
			}
		}
		while ${tempgrp:Inc}<${grpcnt}

		if ${highesthp}
		{
			EQ2Echo Setting MainAssist to ${MainAssist}
			return
		}

		if ${Me.Archetype.Equal[priest]}
		{
			highesthp:Set[${Me.MaxHealth}]
			MainTank:Set[TRUE]
			MainAssist:Set[${Me.Name}]
		}

		tempgrp:Set[1]
		do
		{
			switch ${Me.Group[${tempgrp}].Class}
			{
				case inquisitor
				case templar
				case fury
				case warden
				case defiler
				case mystic
					if ${Me.Group[${tempgrp}].MaxHitPoints}>${highesthp}
					{
						highesthp:Set[${Me.Group[${tempgrp}].MaxHitPoints}]
						MainTank:Set[FALSE]
						MainAssist:Set[${Me.Group[${tempgrp}].Name}]
					}
			}
		}
		while ${tempgrp:Inc}<${grpcnt}

		if ${highesthp}
		{
			EQ2Echo Setting MainAssist to ${MainAssist}
			return
		}
	}



	method PriestPower()
	{
		variable int tempvar=1

		if !${CheckPriestPower}
		{
			priesthaspower:Set[TRUE]
		}

		priesthaspower:Set[FALSE]
		do
		{
			switch ${Me.Group[${tempvar}].Class}
			{
				case priest
				case cleric
				case templar
				case inquisitor
				case druid
				case fury
				case warden
				case shaman
				case defiler
				case mystic
					if ${Me.Group[${tempvar}].Level}>=12 && ${Actor[${Me.ID}].Effect[${reactivespell}](exists)} && ${KeepReactive} && ${Me.Group[${tempvar}].ToActor.Power}>80
					{
						priesthaspower:Set[TRUE]
					}
					elseif ${Me.Group[${tempvar}].ToActor.Power}>80 && !${KeepReactive}
					{
						priesthaspower:Set[TRUE]
	
					}
					return
				case default
					break
			}
		}
		while ${tempvar:Inc}<${Me.GroupCount}

		priesthaspower:Set[TRUE]
	}


}

function atexit()
{
	EQ2Echo Ending EQ2Bot!
	CurrentTask:Set[FALSE]
	SettingXML[${charfile}]:Unload
	SettingXML[${spellfile}]:Unload	

	ui -unload "${LavishScript.HomeDirectory}/Interface/eq2skin.xml"
	ui -unload "${LavishScript.HomeDirectory}/Scripts/EQ2Bot/UI/eq2bot.xml"

	if ${Following}
	{
		FollowTask:Set[0]
	}

	squelch bind -delete EndBot

	DeleteVariable CurrentTask

	press -release ${forward}
	press -release ${backward}
	press -release ${strafeleft}
	press -release ${straferight}
}
