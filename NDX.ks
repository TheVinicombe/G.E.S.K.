//EXECUTES A MANEUVER INCLUDING STEERING AND WARPING

Set ND to NEXTNODE.		//ND is the next MANEUVER node
Set DV0 to ND:DELTAV. 	//DV0 is the total deltaV of the burn
Set TVAL to 0.			//TVAL is the thrust setting
Lock THROTTLE to TVAL.
SAS off.
RCS on.

Set ISP to 0.			//The specific impulse of the active engines of the ship
List ENGINES in ENGLIST.
For ENG in ENGLIST { If ENG:IGNITION {Set ISP to ENG:VISP.} }

Set MODE to 1. 
If (ISP*9.81*ln(SHIP:MASS/SHIP:DRYMASS))<DV0:MAG { Set MODE to 0.5. }         //this prevents trying to do burns without enough fuel

If ISP=0 {Print "THERE ARE NO ACTIVE ENGINES". Set MODE to 0.}

Until MODE = 0 {
	If MODE = 0.5 {
		//DEALS WITH INSUFFICIENT DELTAV
		PRINT "ESTIMATED DELTAV: " + round(ISP*9.81*ln(SHIP:MASS/SHIP:DRYMASS)) + " m/s".
		Print "INSUFFICIENT DELTAV!".
		Set BOX to GUI(200).
		Set L1 to BOX:ADDLABEL("INSUFFICIENT DELTAV!").
		Set L1 to BOX:ADDLABEL("DO YOU WISH TO PROCEED ANYWAY?").
		Set NO to BOX:ADDBUTTON("NO").
		Set NO:ONCLICK to {Set MODE to 0. Print "MANEUVER ABORTED".}.
		Set YES to BOX:ADDBUTTON("YES").
		Set YES:ONCLICK to {Set MODE to 1. Print "RESUMING MANEUVER PROGRAM".}.
		BOX:SHOW.
		Wait until NOT(MODE=0.5).
		BOX:HIDE.
		}
		
	Else if MODE = 1 {
		//Calculates the burn start time and aligns the ship if appropriate
		Set AvMa to (0.5*SHIP:MASS*(1+1/(CONSTANT:E^(DV0:MAG/(2*ISP*9.81))))).     //AvMa is the average mass during the burn
		Set AvAc to SHIP:AVAILABLETHRUST/AvMa.                                           //AvAc is the average acceleration during the burn
		Set BuStTi to DV0:MAG/(2*(AvAc)).                                          //BuStTi is the number of seconds prior to the node that the burn must start
		If ALTITUDE>70000 or not(SHIP:ORBIT:BODY:ATM:EXISTS) {                           //will not align the ship if in the atmosphere
			Print "ALIGNING SHIP WITH MANEUVER NODE".
			Lock STEERING to DV0 + R(0,0,0).
			Wait until Vdot(DV0:NORMALIZED,SHIP:FACING:FOREVECTOR:NORMALIZED)>0.99.
			}
		If ND:ETA>(BuStTi+65){ Set MODE to 2. }
		Else {Set MODE to 3.}
		}
		
	Else if MODE = 2{
		//Performs the warping
		Set BOX2 to GUI(200).   Set BOX2:X to -100.  Set BOX2:Y to 400.
		Set L2 to BOX2:ADDLABEL("CLICK TO CANCEL WARP").
		Set CnWp to BOX2:ADDBUTTON("CANCEL WARP").
		Set CnWp:ONCLICK to {Set MODE to 3. Print "WARP CANCELLED".}.
		BOX2:SHOW().
		Wait 3.
		Until ND:ETA<(BuStTi+30) or MODE=3 {  Set WARP to CEILING(LOG10(ND:ETA-BuStTi-28)).  Wait 0.5.  }
		Set WARP to 0.
		BOX2:HIDE.
		Set MODE to 3.
		}
		
	Else if MODE = 3 {
		//performs the burn
		Print "WAITING FOR BURN".
		Wait until(ND:ETA < (BuStTi+10)).
		Print "TEN SECONDS UNTIL BURN".
		Lock STEERING to DV0 + R(0,0,0).
		Wait until(ND:ETA < BuStTi).
		Print "COMMENCING BURN!".
		Set End to false.
		Until End = true or MODE=9 {
			Set MxAc to (SHIP:AVAILABLETHRUST+0.01)/SHIP:MASS. 																	//MxAc is the maximum acceleration of the ship at the given time
			Set TVAL to min(ND:DELTAV:MAG/MxAc,1).																				//this sets the throttle at 1 until there is less than one second to go, and gradually decreases TVAL thereafter
			If vdot(DV0,ND:DELTAV)<0 { Print "BURN COMPLETE!". Set End to true. }												//this will stop the burn as soon as the initial burn vector and the current burn vector are opposite directions
			If ND:DELTAV:MAG<0.5  { Wait until vdot(DV0,ND:DELTAV)<0.5. Print "BURN COMPLETE!". Set End to true. }				//what to do when there is a very small amount of burn left
			If MAXTHRUST = 0 { 																									//what to do if 
				If SHIP:OXIDIZER = 0 and SHIP:LIQUIDFUEL = 0 { Print "RUN OUT OF FUEL!". Set End to true. }						//ends the program if the ship runs out of fuel
				If SHIP:OXIDIZER > 0 or SHIP:LIQUIDFUEL > 0  { STAGE. PRINT "STAGING". Print " ". }								//staging if the ship still has other fuel available
				}
			}
		Set TVAL to 0.
		Print "OUTSTANDING DV:  " + round(ND:DELTAV:MAG,2) + " m/s".
		Unlock STEERING.
		Remove ND.
		Set MODE to 0.
		}
	}
	RCS off.
	Set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.