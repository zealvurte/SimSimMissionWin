-- [ Output raw Lua for copy & paste to file ]
local function print_raw(value,string,depth,indent,keyOrder,comments)
	depth = depth or 0
	indent = indent or 0
	if type(value)=="table" then
		if string == "" then
			print("{")
		else
			string = string.."{"
		end
		local d = depth+1
		local hb, pb
		local kt = value
		kt = {}
		for k in pairs(value) do
			table.insert(kt,k)
		end
		local ko = keyOrder and #keyOrder > 0 and keyOrder[d] or (keyOrder and #keyOrder == 0 and keyOrder or nil)
		table.sort(kt,function (a,b)
			if ko and (type(a) == "string" or type(b) == "string") then return (ko[a] or math.huge) < (ko[b] or math.huge)
			else return a < b end
		end)
		local cid = 0
		for i,k in ipairs(kt) do
			local v = value[k]
			if type(v)=="table" then
				cid = k
				local b
				local c = comments
				if type(k) == "number" then
					if string ~= "" then
						local pc = c and type(c) == "table" and kt[i-1] and c[kt[i-1]]
						print((string:gsub(', }',"}"):gsub(' $',""))..(pc and type(pc) == "string" and pc or ""))
						string = ""
						c = c and type(c) == "table" and c[k]
					end
					string = ("	"):rep(indent+1).."["..k.."]="
					b = true
				else
					string = string..k.."="
					b = false
				end
				string = print_raw(v,string,d,type(k) == "number" and indent+1 or indent,keyOrder,type(k) == "number" and c or comments)
				hb = hb or b
				pb = b
			else
				string = string..(type(k) == "string" and k or "["..k.."]").."="
				if k == "flags" and v then v = string.format("0x%0x",v) end
				string = print_raw(v,string,d,indent,keyOrder,comments)
			end
		end
		local c = comments and type(comments) == "table" and comments[cid]
		if string == "" then
			print("}"..(c and type(c) == "string" and c or ""))
		elseif hb then
			if string ~= "" then
				print((string:gsub(', }',"}"):gsub(' $',""))..(c and type(c) == "string" and c or ""))
			end
			string = ("	"):rep(indent).."}, "
		else
			string = string.."}, "
		end
		return string
	elseif type(value)=="string" and not value:match('^0x') then
		return string..'"'..value..'", '
	else
		return string..tostring(value)..", "
	end
end

-- [ Parse TSV ]
local headers = {
	"id",
	"name",
	"cooldown",
	"duration",
	"flags",
	"schoolMask",
	"effect.index",
	"effect.type",
	"effect.points",
	"effect.target",
	"effect.flags",
	"effect.period",
	"effect.description",
	"effect.status",
	"effect.notes",
}
local spellKeys = {
	name = 1,
	cooldown = 2,
	duration = 3,
	flags = 4,
	schoolMask = 5,
	effects = 6,
}
local effectKeys = {
	type = 1,
	points = 2,
	target = 3,
	flags = 4,
	period = 5,
	description = 6,
	status = 7,
	notes = 8,
}
local function parseTSV(data,rawOutput)
	local d, i, q = {}, 0, false
	for s in data:gmatch('[^\r\n]+') do
		local qs, qe
		if q then	-- In quoted string, so remove tabs until it ends
			qs, qe = s:find('"	')
			local s1, s2 = d[i][q]
			if not qs then
				qs, qe = s:find('"$')
				if not qs then	-- Quoted string continues on next line
					s2 = s
				else	-- Quoted string ends at the end of the line
					s2 = s:sub(1,qs-1)
				end
				s2 = s2:gsub('	'," "):gsub('[\"]','\\%1'):gsub('^ +',""):gsub(' +$',"")
				d[i][q] = s1 and s2 and s1.." "..s2 or s1 or s2
				q = not qs and q
				s = nil
			else	-- Quoted string ends before the end of the line
				s2 = s:sub(1,qs-1):gsub('	'," "):gsub('[\"]','\\%1'):gsub('^ +',""):gsub(' +$',"")
				d[i][q] = s1 and s2 and s1.." "..s2 or s1 or s2
				q = false
				s = s:sub(qe+1)
			end
		else
			i = i+1
		end
		if s then
			qs, qe = s:find('^"')
			if not qs then qs, qe = s:find('	"') end
			while qs do	-- Parse quoted strings and remove tabs first
				local qs2, qe2 = s:find('"	',qe)
				local s1, s2 = s:sub(1,qs-1)
				if not qs2 then
					qs2, qe2 = s:find('"$',qe)
					if not qs2 then	-- Quoted string continues on next line
						s2 = s:sub(qe+1)
						q = true
					else	-- Quoted string ends at the end of the line
						s2 = s:sub(qe+1,qs2-1)
						q = false
					end
					s2 = s2:gsub('	'," "):gsub('[\"]','\\%1')
					s = s1 and s2 and s1.."	"..s2 or s1 or s2
					qs, qe = nil
					break
				else	-- Quoted string ends before the end of the line
					s2 = s:sub(qe+1,qs2-1):gsub('	'," "):gsub('[\"]','\\%1')
					s = s:sub(qe2+1)
					s = s and s2 and s2.."	"..s or s or s2
					s = s and s1 and s1.."	"..s or s or s1
					qs, qe = s:find('	"',qe2)
				end
			end
			if not d[i] then d[i] = {} end
			local d2 = d[i]
			local d2i = 0
			while s:match('		') do s = s:gsub('		',"	nil	") end
			for v in s:gmatch('[^	]+') do	-- Parse tab delimited values
				d2i=d2i+1
				d2[headers[d2i]] = v:gsub('nil',""):gsub('[\"]','\\%1'):gsub('^ +',""):gsub(' +$',"")
			end
			q = q and headers[d2i]
			d2 = nil
		end
	end
	data = {}
	for i,t in ipairs(d) do
		sid = tonumber(t.id)
		sex = t["effect.index"]
		local sd = data[sid]
		if not sd then
			data[sid] = {}
			sd = data[sid]
		end
		local sed = sd.effects
		if sed then
			if sex then
				if #sed == 0 then sd.effects = {[1]=sed} end
				sd.effects[sex+1] = {}
				sed = sd.effects[sex+1]
			else
				sed = nil
			end
		elseif sex then
			sd.effects = {}
			sed = sd.effects
		end
		for k,v in pairs(t) do
			if v then
				if k:find("%.flags") then v = tonumber(v,2)
				elseif tonumber(v) then v = tonumber(v) end
				if k:find("effect%.") then
					if sed and k ~= "effect.index" then
						if k == "effect.status" then
							if v == "TRUE" then v = "VERIFIED"
							elseif v == "FALSE" then v = "INVALID"
							elseif v == "#N/A" then v = "UNUSED"
							else v = "UNVERFIED" end
						elseif k == "effect.notes" and v then
							v = v:gsub("Unused ?","")
						end
						if v == 0 or v == "" then v = nil end
						sed[k:gsub("effect%.","")] = v
					end
				elseif k ~= "id" then
					if v == 0 or v == "" then v = nil end
					sd[k] = v
				end
			end
		end
	end
	d = nil
	if rawOutput then
		local s = print_raw(data,"",0,0,{nil,spellKeys,effectKeys,effectKeys})
		if s and s ~= "" then print((s:gsub(', }',"}"):gsub(' $',""):gsub('},$',"}"))) end
	end
	return data
end

-- [ Convert to VP Spell Effects ]
local environmentStats = {
	[223] = {60,2},
	[228] = {500,2},
	[230] = {50,2},
	[300] = {10,2},
}
local VPKeys = {
	type=1,
	points=2,
	damage=2,
	damageATK=2,
	damagePerc=2,
	heal=2,
	healATK=2,
	healPerc=2,
	healPercent=2,
	plusDamageDealt=2,
	plusDamageDealtATK=2,
	modDamageDealt=2,
	plusDamageTaken=2,
	plusDamageTakenATK=2,
	modDamageTaken=2,
	thornsATK=2,
	thornsPerc=2,
	modMaxHP=2,
	modMaxHPATK=2,
	cATKa=2.1,
	cATKb=2.2,
	target=3,
	flags=4,
	duration=4,
	shroudTurns=4,
	period=5,
	firstTurn=6,
	noFirstTick=7,
	nore=8,
	dne=9,
	description=10,
	status=11,
	notes=12,
}
local function convertToVPSpellEffect(effect,id,name,duration,cooldown,flags,environmentStats,previousEffect,useOriginalVP)
	if not effect.type or not effect.target then return {type="nop"} end
	effect.index=nil
	local t=effect.type
	effect.type=nil
	local p=effect.points
	effect.points=nil
	if not duration and not cooldown and t > 4 then effect.type="passive"
	elseif t > 4 and t ~= 9 and t ~= 10 then effect.type="aura"
	elseif t == 1 or t == 3 then effect.type="nuke"
	elseif t == 2 or t == 4 then effect.type="heal"
	elseif t == 9 then effect.type="taunt"
	elseif useOriginalVP and t == 10 then effect.type="heal" -- Detaunt used to be marked as a type=heal
	elseif t == 10 then effect.type="shroud" end	-- Mark detaunts as type="shroud"
	if t ~= 12 and t ~= 14 and effect.flags and effect.flags&2^0 ~= 0 then
		if t == 1 or t == 2 or t == 11 or t == 13 or t == 15 then p=100	-- Always 100% of source.attack
		else p=p and tonumber((tostring(p*100):gsub("%.0+",""))) or 0 end
		if t == 1 or t == 3 or t == 5 or t == 7 then effect.damageATK=p
		elseif t == 2 or t == 4 or t == 6 or t == 8 then effect.healATK=p
		elseif t == 11 or t == 19 then effect.plusDamageDealtATK=p
		elseif t == 13 or t == 20 then effect.plusDamageTakenATK=p
		elseif t == 15 or t == 16 then effect.thornsATK=p
		elseif t == 17 or t == 18 then effect.modMaxHPATK=p end
	else
		if t ~= 1 and t ~= 2 and t ~= 5 and t ~= 6 and t ~= 15 and t ~= 17 then p=p and tonumber((tostring(p*100):gsub("%.0+",""))) or 0 end
		if t == 1 or t == 5 then effect.damage=p	-- VP has not implemented it
		elseif t == 3 or t == 7 then effect.damagePerc=p
		elseif t == 2 or t == 6 then effect.heal=p	-- VP has not implemented it
		elseif t == 4 and useOriginalVP then effect.healPercent=p	-- VP used to use a different key just for direct heals
		elseif t == 4 or t == 8 then effect.healPerc=p
		elseif t == 11 then effect.plusDamageDealt=p
		elseif t == 12 or t == 19 then effect.modDamageDealt=p	-- 12 is always %
		elseif t == 13 then effect.plusDamageTaken=p
		elseif t == 14 or t == 20 then effect.modDamageTaken=p	-- 14 is always %
		elseif t == 15 then effect.thorns=p	-- VP has not implemented it
		elseif t == 16 then effect.thornsPerc=p
		elseif t == 17 then effect.modMaxHPFlat=p	-- VP has not implemented it
		elseif t == 18 then effect.modMaxHP=p end
	end
	if useOriginalVP and t == 10 and duration then	-- Detaunts used to use duration as a separate shroudTurns value because they were reusing type=heal
		effect.duration=nil
		effect.shroudTurns=duration
	elseif duration and effect.type == "aura" or effect.type == "taunt" or effect.type == "shroud" then effect.duration=duration end
	if t > 4 and t < 9 then
		if duration then effect.duration=duration+1
		elseif not duration then effect.duration=1 end
		effect.period=effect.period and effect.period > 1 and effect.period or nil
		if not effect.flags or effect.flags&2^1 == 0 then effect.noFirstTick=true end
		if not effect.noFirstTick then effect.nore=true end
		if useOriginalVP and effect.period and effect.period > 1 and effect.duration and effect.period <= effect.duration and effect.duration/effect.period < 2 then	-- Periodic ticks greater than 2 that won't repeat within the duration used to use echo instead
			effect.type=effect.noFirstTick and "aura" or "nuke"
			effect.echo=effect.period
			effect.period=nil
			effect.duration=effect.noFirstTick and 0 or (effect.type == "aura" and 1 or nil)
		end
	else effect.period=nil end
	if effect.target == 1 then effect.target=4
	elseif effect.target == 2 then effect.target=3
	elseif effect.target == 3 then effect.target=0
	elseif effect.target == 4 then effect.target=5
	elseif effect.target == 5 then effect.target=1
	elseif effect.target == 6 then effect.target="all-allies"
	elseif effect.target == 7 then effect.target="all-enemies"
	elseif effect.target == 8 then effect.target="friend-surround"
	elseif effect.target == 9 then effect.target="cleave"
	elseif effect.target == 10 then
		if false then effect.target=3	-- No known cases of followers using friend-col, and VP has not implemented it
		elseif id == 142 or id == 213 then effect.target=3	-- All known encounter cases target the back row, so can't find additional targets behind it, and VP has not implemented it
		else effect.target="friend-cone" end
	elseif effect.target == 11 then effect.target="cone"
	elseif effect.target == 12 then
		if false then effect.target=3	-- No known cases of encounters using friend-col, and VP has not implemented it
		elseif false then effect.target=3	-- No known cases of followers using friend-col, and VP has not implemented it
		else effect.target="friend-col" end
	elseif effect.target == 13 then
		if id == 73 or id == 102 then effect.target="col"	-- Followers using col
		else effect.target=0 end	-- Always closest enemy for encounters because it doesn't work on followers
	elseif effect.target == 14 then
		if effect.type == "heal" then effect.target="friend-front-soft"	-- Include self in the same row for heals
		elseif effect.type == "aura" then effect.target="friend-front-hard"	-- Exclude self in the same row for auras
		else effect.target="friend-front" end
	elseif effect.target == 15 then effect.target="enemy-front"
	elseif effect.target == 16 then
		if effect.type == "heal" then effect.target="friend-back-soft"	-- Include self in the same row for heals
		elseif effect.type == "aura" then effect.target="friend-back-hard"	-- Exclude self in the same row for auras
		else effect.target="friend-back" end
	elseif effect.target == 17 then effect.target="enemy-back"
	elseif effect.target == 18 then effect.target="all"
	elseif effect.target == 19 then effect.target="random-all"
	elseif effect.target == 20 then	-- Random follower
		if id == 120 or id == 122 or id == 125 or id == 180 or id == 227 or id == 231 or id == 232 or id == 301 then effect.target="random-enemy"	-- Encounters will target a random enemy
		else effect.target="random-ally" end	-- Followers will target a random ally
	elseif effect.target == 21 then	-- Random encounter
		if id == 166 or id == 208 or id == 209 or id == 229 or id == 234 or id == 298 then effect.target="random-ally"	-- Encounters will target a random ally
		else effect.target="random-enemy" end	-- Followers will target a random enemy
	elseif effect.target == 22 then effect.target="all-other-allies"
	elseif effect.target == 23 then effect.target="all-enemies"	-- All followers (only used by environment)
	elseif effect.target == 24 then effect.target="all-allies" end	-- All encounters (only used by environment)
	if environmentStats then	-- Environments need their stats explicitly defined on their effects for VP
		effect.cATKa = environmentStats[1]
		effect.cATKb = environmentStats[2]
	end
	if previousEffect and previousEffect.type == "aura" and effect.type == "aura" and (previousEffect.damageATK or previousEffect.damagePerc or previousEffect.healATK or previousEffect.healPerc or previousEffect.healPercent) and (effect.damageATK or effect.damagePerc or effect.healATK or effect.healPerc or effect.healPercent) then previousEffect.dne=true end	-- Still not sure on this, but seemingly prevents a death from the previous effect from ending the sim immediately, as this effect still needs to happen
	effect.flags=nil
	effect.notes=effect.notes and effect.notes:gsub('Corrections:',"#Bug/#Fix: corrected to"):gsub('Ignored:',"#Bug/#Workaround: ignored"):gsub('To-do:',"#ToDo:")
	local c=string.format("	-- %s: %s [%s]%s",name,effect.description,effect.status,effect.notes and " "..effect.notes or "")
	effect.description=nil
	effect.status=nil
	effect.notes=nil
	return effect, c
end
local function convertToVP(data,environmentStats,rawOutput,useOriginalVP)
	local c = {}
	for sid,s in pairs(data) do
		local ses = s.effects
		local secs
		if ses then
			local es
			if environmentStats[sid] then es = environmentStats[sid] end
			if s.flags and s.flags&2^0 ~= 0 then ses.firstTurn=s.cooldown end
			if #ses == 0 then
				local sec
				ses, sec = convertToVPSpellEffect(ses,sid,s.name,s.duration,s.cooldown,s.flags,es,nil,useOriginalVP)
				secs = sec
			else
				secs = {}
				local pse
				for sex,se in ipairs(ses) do
					local sec
					se, sec = convertToVPSpellEffect(se,sid,s.name,s.duration,s.cooldown,s.flags,es,pse,useOriginalVP)
					ses[sex] = se
					secs[sex] = sec
					pse = se
				end
			end
		end
		data[sid] = ses
		c[sid] = secs
	end
	if rawOutput then
		local s = print_raw(data,"",0,0,VPKeys,c)
		if s and s ~= "" then print((s:gsub(', }',"}"):gsub(' $',""):gsub('},$',"}"))) end
	end
	return data, c
end

-- [ Compare against VP data ]
local vpData = {
	[1]={type="nuke", damageATK=100, target="all-allies"},	-- DNT JasonTest Envirospell: Damage all encounters for (1*attack) [UNUSED]
	[2]={firstTurn=4,
		[1]={type="aura", plusDamageDealtATK=20, target="all-other-allies", duration=2},	-- DNT JasonTest Ability Spell: Mod damage done of all-other allies by (0.2*attack) for 2 rounds [UNUSED] #Bug/#Workaround: ignored ineffective Effect.Period
		[2]={type="heal", healPerc=100, target=4},	-- DNT JasonTest Ability Spell: Heal self for 100% [UNUSED]
	},
	[3]={
		[1]={type="heal", heal=45.2, target=4},	-- DNT Owen Test Double Effect: Heal self for 45.2 [UNUSED]
		[2]={type="nuke", damage=90.4, target=0},	-- DNT Owen Test Double Effect: Damage closest enemy for 90.4 [UNUSED]
	},
	[4]={
		[1]={type="nuke", damageATK=75, target=0},	-- Double Strike: Damage closest enemy for (0.75*attack) [UNVERFIED]
		[2]={type="nuke", damageATK=50, target=0},	-- Double Strike: Damage closest enemy for (0.5*attack) [UNVERFIED]
	},
	[5]={type="nuke", damageATK=10, target="all-enemies"},	-- Wing Sweep: Damage all enemies for (0.1*attack) [UNVERFIED]
	[6]={type="nuke", damageATK=60, target="enemy-back"},	-- Blood Explosion: Damage backmost row of enemies for (0.6*attack) [UNVERFIED]
	[7]={type="nuke", damageATK=10, target=0},	-- Skeleton Smash: Damage closest enemy for (0.1*attack) [VERIFIED]
	[8]={type="nuke", damageATK=100, target=0},	-- Hawk Punch: Damage closest enemy for (1*attack) [UNUSED] #Bug/#Workaround: ignored incorrect Effect.Type, or ineffective Effect.Points
	[9]={type="heal", healPerc=5, target="all-allies"},	-- Healing Howl: Heal all allies for 5% [VERIFIED]
	[10]={
		[1]={type="nuke", damagePerc=20, target=0},	-- Starbranch Crush: Damage closest enemy for 20% [VERIFIED]
		[2]={type="aura", damagePerc=3, target="all-enemies", duration=4, noFirstTick=true, dne=true},	-- Starbranch Crush: Damage (tick) all enemies for 3% each subsequent round for 3 rounds [VERIFIED] To-do: test dne=true behaviour
		[3]={type="aura", healPerc=1, target=4, duration=4, noFirstTick=true},	-- Starbranch Crush: Heal (tick) self for 1% each subsequent round for 3 rounds [VERIFIED]
	},
	[11]={type="nuke", damageATK=100, target=0},	-- Auto Attack: Damage closest enemy for (1*attack) [VERIFIED]
	[12]={type="heal", healATK=20, target="all-allies"},	-- Bone Reconstruction: Heal all allies for (0.2*attack) [VERIFIED]
	[13]={type="heal", heal=10, target=3},	-- Gentle Caress: Heal closest ally for 10 [UNUSED]
	[14]={type="heal", healATK=10, target="all-allies"},	-- Spirit's Caress: Heal all allies for (0.1*attack) [UNUSED]
	[15]={type="nuke", damageATK=100, target=1},	-- Auto Attack: Damage furthest enemy for (1*attack) [VERIFIED] #Bug/#Workaround: ignored incorrect Effect.Type
	[16]={type="nuke", damageATK=75, target=1},	-- Soulshatter: Damage furthest enemy for (0.75*attack) [UNVERFIED]
	[17]={
		[1]={type="nuke", damageATK=10, target="all-enemies"},	-- Gravedirt Special: Damage all enemies for (0.1*attack) [VERIFIED]
		[2]={type="heal", healATK=100, target=4},	-- Gravedirt Special: Heal self for (1*attack) [VERIFIED] #Bug/#Workaround: ignored incorrect Effect.Type, or ineffective Effect.Points
		[3]={type="nop"},
	},
	[18]={
		[1]={type="nuke", damageATK=20, target="enemy-front"},	-- Wings of Fury: Damage frontmost row of enemies for (0.2*attack) [UNVERFIED]
		[2]={type="nuke", damageATK=20, target="enemy-front"},	-- Wings of Fury: Damage frontmost row of enemies for (0.2*attack) [UNVERFIED]
		[3]={type="nuke", damageATK=20, target="enemy-front"},	-- Wings of Fury: Damage frontmost row of enemies for (0.2*attack) [UNVERFIED]
	},
	[19]={type="nuke", damageATK=150, target=0},	-- Searing Bite: Damage closest enemy for (1.5*attack) [VERIFIED]
	[20]={type="nuke", damageATK=70, target="enemy-back"},	-- Huck Stone: Damage backmost row of enemies for (0.7*attack) [UNVERFIED]
	[21]={type="aura", healATK=25, target="all-allies", duration=5, noFirstTick=true},	-- Spirits of Rejuvenation: Heal (tick) all allies for (0.25*attack) each subsequent round for 4 rounds [VERIFIED]
	[22]={
		[1]={type="nuke", damageATK=90, target="cleave"},	-- Unrelenting Hunger: Damage closest enemies for (0.9*attack) [UNVERFIED]
		[2]={type="aura", damageATK=10, target="cleave", duration=3, noFirstTick=true},	-- Unrelenting Hunger: Damage (tick) closest enemies for (0.1*attack) each subsequent round for 2 rounds [UNVERFIED]
	},
	[23]={
		[1]={type="shroud", target=4, duration=2},	-- DNT JasonTest Taunt Spell: Detaunt self for 2 rounds [UNUSED] #Bug/#Workaround: ignored ineffective Effect.Points
		[2]={type="aura", damagePerc=10, target="cone", duration=3, noFirstTick=true},	-- DNT JasonTest Taunt Spell: Damage (tick) closest cone of enemies for 10% each subsequent round for 2 rounds [UNUSED]
	},
	[24]={
		[1]={type="nuke", damageATK=180, target=1},	-- Shining Spear: Damage furthest enemy for (1.8*attack) [VERIFIED]
		[2]={type="heal", healATK=20, target=3},	-- Shining Spear: Heal closest ally for (0.2*attack) [VERIFIED]
	},
	[25]={
		[1]={type="nuke", damageATK=50, target="enemy-front"},	-- Whirling Fists: Damage frontmost row of enemies for (0.5*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=20, target=4, duration=3},	-- Whirling Fists: Mod damage done of self by 20% for 3 rounds [VERIFIED]
	},
	[26]={
		[1]={type="heal", healATK=100, target=3},	-- Physiker's Potion: Heal closest ally for (1*attack) [VERIFIED]
		[2]={type="aura", modMaxHPATK=20, target=3, duration=2},	-- Physiker's Potion: Mod max health of closest ally by (0.2*attack) for 2 rounds [VERIFIED]
	},
	[27]={type="nuke", damageATK=100, target=0},	-- XX - Test - Physical: Damage closest enemy for (1*attack) [UNUSED]
	[28]={type="nuke", damageATK=100, target=0},	-- XX - Test - Melee - Holy: Damage closest enemy for (1*attack) [UNUSED]
	[29]={type="nuke", damageATK=100, target=0},	-- XX - Test - Melee - Fire: Damage closest enemy for (1*attack) [UNUSED]
	[30]={type="nuke", damageATK=100, target=0},	-- XX - Test - Melee - Nature: Damage closest enemy for (1*attack) [UNUSED]
	[31]={type="nuke", damageATK=100, target=0},	-- XX - Test - Melee - Frost: Damage closest enemy for (1*attack) [UNUSED]
	[32]={type="nuke", damageATK=100, target=0},	-- XX - Test - Melee - Shadow: Damage closest enemy for (1*attack) [UNUSED]
	[33]={type="nuke", damageATK=100, target=0},	-- XX - Test - Melee - Arcane: Damage closest enemy for (1*attack) [UNUSED]
	[34]={type="nuke", damageATK=100, target="all-enemies"},	-- XX - Test - Ranged - Physical: Damage all enemies for (1*attack) [UNUSED]
	[35]={type="nuke", damageATK=100, target="all-enemies"},	-- XX - Test - Ranged - Holy: Damage all enemies for (1*attack) [UNUSED]
	[36]={type="nuke", damageATK=100, target="all-enemies"},	-- XX - Test - Ranged - Fire: Damage all enemies for (1*attack) [UNUSED]
	[37]={type="nuke", damageATK=100, target="all-enemies"},	-- XX - Test - Ranged - Nature: Damage all enemies for (1*attack) [UNUSED]
	[38]={type="nuke", damageATK=100, target="all-enemies"},	-- XX - Test - Ranged - Frost: Damage all enemies for (1*attack) [UNUSED]
	[39]={type="nuke", damageATK=100, target="all-enemies"},	-- XX - Test - Ranged - Shadow: Damage all enemies for (1*attack) [UNUSED]
	[40]={type="nuke", damageATK=100, target="all-enemies"},	-- XX - Test - Ranged - Arcane: Damage all enemies for (1*attack) [UNUSED]
	[41]={type="aura", damageATK=25, target="cleave", duration=1, noFirstTick=true},	-- Bag Smash: Damage (tick) closest enemies for (0.25*attack) each subsequent round for 0 rounds [UNUSED]
	[42]={type="passive", thornsPerc=10, target=4},	-- JasonTest Passive: Damage attacker of self for 10% indefinitely [UNUSED]
	[43]={
		[1]={type="nuke", damageATK=25, target=1},	-- Leech Anima: Damage furthest enemy for (0.25*attack) [VERIFIED]
		[2]={type="heal", healATK=20, target=4},	-- Leech Anima: Heal self for (0.2*attack) [VERIFIED]
	},
	[44]={
		[1]={type="nuke", damageATK=50, target=0},	-- Double Stab: Damage closest enemy for (0.5*attack) [VERIFIED]
		[2]={type="nuke", damageATK=25, target=0},	-- Double Stab: Damage closest enemy for (0.25*attack) [VERIFIED]
	},
	[45]={
		[1]={type="nuke", damageATK=75, target=1},	-- Siphon Soul: Damage furthest enemy for (0.75*attack) [VERIFIED]
		[2]={type="heal", healATK=25, target=4},	-- Siphon Soul: Heal self for (0.25*attack) [VERIFIED]
	},
	[46]={
		[1]={type="aura", modDamageTaken=-10, target=4, duration=1},	-- Shield of Tomorrow: Mod damage taken of self by -10% for 1 rounds [VERIFIED]
		[2]={type="aura", modDamageTaken=-10, target="friend-back-hard", duration=1},	-- Shield of Tomorrow: Mod damage taken of backmost row of allies by -10% for 1 rounds [VERIFIED] To-do: test target=\"*-hard\" behaviour
	},
	[47]={type="passive", modDamageTaken=-20, target="all-allies"},	-- Protective Aura: Mod damage taken of all allies by -20% indefinitely [UNVERFIED]
	[48]={
		[1]={type="shroud", target=4, duration=1},	-- Shadow Walk: Detaunt self for 1 rounds [UNVERFIED]
		[2]={type="heal", healATK=20, target=4},	-- Shadow Walk: Heal self for (0.2*attack) [UNVERFIED]
	},
	[49]={type="aura", modDamageTaken=33, target="enemy-back", duration=4},	-- Exsanguination: Mod damage taken of backmost row of enemies by 33% for 4 rounds [UNVERFIED]
	[50]={type="nuke", damageATK=120, target=1},	-- Halberd Strike: Damage furthest enemy for (1.2*attack) [VERIFIED]
	[51]={type="nuke", damageATK=75, target="enemy-front"},	-- Bonestorm: Damage frontmost row of enemies for (0.75*attack) [UNVERFIED]
	[52]={type="nuke", damageATK=30, target="enemy-back"},	-- Plague Song: Damage backmost row of enemies for (0.3*attack) [UNUSED] #Bug/#Workaround: ignored incorrect Effect.Type
	[53]={
		[1]={type="aura", damageATK=10, target="all-enemies", duration=7, period=2, noFirstTick=true},	-- Bramble Trap: Damage (tick) all enemies for (0.1*attack) each subsequent 2nd round for 6 rounds [UNUSED]
		[2]={type="aura", modDamageDealt=-20, target="all-enemies", duration=6},	-- Bramble Trap: Mod damage done of all enemies by -20% for 6 rounds [UNUSED] #Bug/#Workaround: ignored ineffective Effect.Period
	},
	[54]={
		[1]={type="nuke", damageATK=90, target=0},	-- Slicing Shadows: Damage closest enemy for (0.9*attack) [UNVERFIED]
		[2]={type="nuke", damageATK=90, target=1},	-- Slicing Shadows: Damage furthest enemy for (0.9*attack) [UNVERFIED]
	},
	[55]={type="nuke", damageATK=150, target="enemy-front"},	-- Polite Greeting: Damage frontmost row of enemies for (1.5*attack) [UNVERFIED]
	[56]={type="nuke", damageATK=125, target=1},	-- Mirror of Torment: Damage furthest enemy for (1.25*attack) [UNVERFIED]
	[57]={type="aura", damageATK=100, target=0, duration=4, noFirstTick=true},	-- Etiquette Lesson: Damage (tick) closest enemy for (1*attack) each subsequent round for 3 rounds [UNVERFIED]
	[58]={type="nuke", damageATK=70, target="cleave"},	-- Headcrack: Damage closest enemies for (0.7*attack) [VERIFIED]
	[59]={type="nuke", damageATK=50, target="enemy-back"},	-- Mirrors of Regret: Damage backmost row of enemies for (0.5*attack) [UNVERFIED]
	[60]={type="nuke", damageATK=40, target=1},	-- Acid Spit: Damage furthest enemy for (0.4*attack) [VERIFIED]
	[61]={type="nuke", damageATK=75, target=0},	-- Mandible Smash: Damage closest enemy for (0.75*attack) [VERIFIED]
	[62]={type="nuke", damageATK=30, target="enemy-front"},	-- Gore: Damage frontmost row of enemies for (0.3*attack) [VERIFIED]
	[63]={
		[1]={type="nuke", damageATK=60, target="all-enemies"},	-- Sonic Shriek: Damage all enemies for (0.6*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-20, target="all-enemies", duration=2},	-- Sonic Shriek: Mod damage done of all enemies by -20% for 2 rounds [VERIFIED]
	},
	[64]={type="nuke", damageATK=150, target="all-enemies"},	-- Massive Rumble: Damage all enemies for (1.5*attack) [VERIFIED]
	[65]={type="nuke", damageATK=65, target=0},	-- Nagging Doubt: Damage closest enemy for (0.65*attack) [UNUSED]
	[66]={type="nuke", damageATK=150, target=0},	-- Goliath Slam: Damage closest column of enemies for (1.5*attack) [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Target
	[67]={type="nuke", damageATK=120, target=1},	-- Vault Strike: Damage furthest enemy for (1.2*attack) [UNUSED]
	[68]={firstTurn=3,
		[1]={type="nuke", damageATK=20, target="enemy-front"},	-- Glowhoof Trample: Damage frontmost row of enemies for (0.2*attack) [UNUSED]
		[2]={type="aura", modDamageDealt=-80, target="enemy-front", duration=1},	-- Glowhoof Trample: Mod damage done of frontmost row of enemies by -80% for 1 rounds [UNUSED] #Bug/#Workaround: ignored incorrect Effect.Flags
	},
	[69]={
		[1]={type="nuke", damageATK=100, target=4},	-- DNT JasonTest Ability Spell2: Damage self for (1*attack) [UNUSED] #Bug/#Workaround: ignored incorrect Effect.Type, and ineffective Effect.Period
		[2]={type="nuke", damageATK=20, target=4},	-- DNT JasonTest Ability Spell2: Damage self for (0.2*attack) [UNUSED]
		[3]={type="nuke", damage=50, target=4},	-- DNT JasonTest Ability Spell2: Damage self for 50 [UNUSED]
		[4]={type="nop"},
	},
	[70]={type="nop"},
	[71]={type="heal", healATK=100, target=3},	-- Revitalizing Vines: Heal closest ally for (1*attack) [VERIFIED] #Bug/#Workaround: ignored incorrect Effect.Type
	[72]={
		[1]={type="nuke", damageATK=200, target=0},	-- Resonating Strike: Damage closest enemy for (2*attack) [VERIFIED]
		[2]={type="nuke", damageATK=40, target="enemy-back"},	-- Resonating Strike: Damage backmost row of enemies for (0.4*attack) [VERIFIED]
	},
	[73]={type="nuke", damageATK=100, target="col"},	-- Purification Ray: Damage closest column of enemies for (1*attack) [VERIFIED]
	[74]={
		[1]={type="aura", modDamageTaken=-40, target=4, duration=3},	-- Reconfiguration: Defense: Mod damage taken of self by -40% for 3 rounds [VERIFIED]
		[2]={type="aura", modDamageDealt=-40, target=4, duration=3},	-- Reconfiguration: Defense: Mod damage done of self by -40% for 3 rounds [VERIFIED]
	},
	[75]={type="nuke", damageATK=150, target=1},	-- Larion Leap: Damage furthest enemy for (1.5*attack) [VERIFIED]
	[76]={type="nuke", damageATK=225, target=1},	-- Phalynx Flash: Damage furthest enemy for (2.25*attack) [UNVERFIED]
	[77]={type="aura", plusDamageDealtATK=20, target="all-allies", duration=3},	-- Potions of Penultimate Power: Mod damage done of all allies by (0.2*attack) for 3 rounds [VERIFIED]
	[78]={type="nuke", damageATK=30, target="enemy-front"},	-- Cleave: Damage frontmost row of enemies for (0.3*attack) [VERIFIED]
	[79]={
		[1]={type="nuke", damageATK=20, target="all-enemies"},	-- Holy Nova: Damage all enemies for (0.2*attack) [VERIFIED]
		[2]={type="heal", healATK=20, target="all-allies"},	-- Holy Nova: Heal all allies for (0.2*attack) [VERIFIED]
	},
	[80]={
		[1]={type="nuke", damageATK=120, target=1},	-- Dawnshock: Damage furthest enemy for (1.2*attack) [VERIFIED]
		[2]={type="aura", damageATK=40, target=1, duration=3, noFirstTick=true},	-- Dawnshock: Damage (tick) furthest enemy for (0.4*attack) each subsequent round for 2 rounds [VERIFIED]
	},
	[81]={type="aura", thornsATK=100, target=4, duration=3},	-- Reconfiguration: Reflect: Damage attacker of self for (1*attack) for 3 rounds [VERIFIED] #Bug/#Workaround: ignored incorrect Effect.Type
	[82]={type="passive", thornsATK=25, target=4},	-- Mace to Hand: Damage attacker of self for (0.25*attack) indefinitely [VERIFIED]
	[83]={type="nuke", damageATK=120, target="cleave"},	-- Lead the Charge: Damage closest enemies for (1.2*attack) [VERIFIED]
	[84]={type="aura", modDamageDealt=-100, target="all-enemies", duration=2, firstTurn=4},	-- Sparkling Driftglobe Core: Mod damage done of all enemies by -100% for 2 rounds [VERIFIED]
	[85]={type="aura", modDamageTaken=-5000, target=3, duration=2, firstTurn=3},	-- Resilient Plumage: Mod damage taken of closest ally by -5000% for 2 rounds [VERIFIED] #Bug/#Workaround: ignored incorrect Effect.Points
	[86]={type="nuke", damageATK=50, target=0},	-- [PH]Placeholder Punch: Damage closest enemy for (0.5*attack) [UNUSED]
	[87]={type="nuke", damageATK=60, target="enemy-back"},	-- Doubt Defied: Damage backmost row of enemies for (0.6*attack) [VERIFIED]
	[88]={
		[1]={type="aura", modDamageDealt=30, target=4, duration=3},	-- Combat Meditation: Mod damage done of self by 30% for 3 rounds [VERIFIED]
		[2]={type="nuke", damageATK=40, target="all-enemies"},	-- Combat Meditation: Damage all enemies for (0.4*attack) [VERIFIED]
	},
	[89]={type="aura", damageATK=40, target=1, duration=3, nore=true},	-- Spiked Burr Trap: Damage (tick) furthest enemy for (0.4*attack) immediately and each subsequent round for 2 rounds [VERIFIED]
	[90]={type="passive", modDamageDealt=20, target="friend-surround"},	-- Invigorating Herbs: Mod damage done of closest allies by 20% indefinitely [VERIFIED]
	[91]={type="aura", plusDamageDealtATK=-60, target=1, duration=3},	-- Dazzledust: Mod damage done of furthest enemy by (-0.6*attack) for 3 rounds [VERIFIED]
	[92]={type="aura", damageATK=50, target="enemy-back", duration=3, nore=true},	-- Trickster's Torment: Damage (tick) backmost row of enemies for (0.5*attack) immediately and each subsequent round for 2 rounds [VERIFIED]
	[93]={
		[1]={type="nuke", damageATK=20, target=0},	-- Leeching Seed: Damage closest enemy for (0.2*attack) [VERIFIED]
		[2]={type="heal", healATK=80, target=4},	-- Leeching Seed: Heal self for (0.8*attack) [VERIFIED]
	},
	[94]={type="aura", damageATK=30, target="enemy-front", duration=4, noFirstTick=true},	-- Icespore Spear: Damage (tick) frontmost row of enemies for (0.3*attack) each subsequent round for 3 rounds [VERIFIED]
	[95]={
		[1]={type="nuke", damageATK=150, target=1},	-- Starlight Strike: Damage furthest enemy for (1.5*attack) [VERIFIED]
		[2]={type="nuke", damageATK=40, target="enemy-back"},	-- Starlight Strike: Damage backmost row of enemies for (0.4*attack) [VERIFIED]
	},
	[96]={
		[1]={type="nuke", damageATK=60, target=1},	-- Insect Swarm: Damage furthest enemy for (0.6*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-30, target=1, duration=2},	-- Insect Swarm: Mod damage done of furthest enemy by -30% for 2 rounds [VERIFIED]
	},
	[97]={type="nuke", damageATK=90, target="cone"},	-- Flashing Arrows: Damage closest cone of enemies for (0.9*attack) [VERIFIED]
	[98]={type="nuke", damageATK=120, target=1},	-- Anima Bolt: Damage furthest enemy for (1.2*attack) [VERIFIED]
	[99]={type="nuke", damageATK=140, target="enemy-front"},	-- Onslaught: Damage frontmost row of enemies for (1.4*attack) [VERIFIED]
	[100]={type="heal", healATK=60, target=4},	-- Heart of the Forest: Heal self for (0.6*attack) [VERIFIED]
	[101]={
		[1]={type="nuke", damageATK=60, target=0},	-- Strangleheart Seed: Damage closest enemy for (0.6*attack) [VERIFIED]
		[2]={type="aura", modDamageTaken=20, target=0, duration=3},	-- Strangleheart Seed: Mod damage taken of closest enemy by 20% for 3 rounds [VERIFIED]
	},
	[102]={type="nuke", damageATK=30, target="col"},	-- Forest's Touch: Damage closest column of enemies for (0.3*attack) [VERIFIED]
	[103]={type="aura", modDamageDealt=100, target="all-other-allies", duration=2},	-- Social Butterfly: Mod damage done of all-other allies by 100% for 2 rounds [VERIFIED]
	[104]={
		[1]={type="heal", healATK=100, target=3},	-- Podtender: Heal closest ally for (1*attack) [VERIFIED] #Bug/#Workaround: ignored incorrect Effect.Type
		[2]={type="aura", modDamageDealt=-10, target=3, duration=1},	-- Podtender: Mod damage done of closest ally by -10% for 1 rounds [VERIFIED]
	},
	[105]={type="passive", modDamageTaken=-10, target="all-allies"},	-- Hold the Line: Mod damage taken of all allies by -10% indefinitely [VERIFIED]
	[106]={type="nuke", damageATK=40, target="cleave"},	-- Face Your Foes: Damage closest enemies for (0.4*attack) [VERIFIED]
	[107]={
		[1]={type="aura", damageATK=150, target=0, duration=4, nore=true},	-- Volatile Solvent: Damage (tick) closest enemy for (1.5*attack) immediately and each subsequent round for 3 rounds [VERIFIED]
		[2]={type="aura", plusDamageTakenATK=50, target=0, duration=3},	-- Volatile Solvent: Mod damage taken of closest enemy by (0.5*attack) for 3 rounds [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.flags EXTRA_INITIAL_PERIOD
	},
	[108]={
		[1]={type="heal", healATK=40, target=3},	-- Ooz's Frictionless Coating: Heal closest ally for (0.4*attack) [VERIFIED]
		[2]={type="aura", modMaxHP=10, target=3, duration=2},	-- Ooz's Frictionless Coating: Mod max health of closest ally by 10% for 2 rounds [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.flags EXTRA_INITIAL_PERIOD
	},
	[109]={type="passive", thornsATK=60, target=4},	-- Serrated Shoulder Blades: Damage attacker of self for (0.6*attack) indefinitely [UNVERFIED]
	[110]={type="heal", healATK=40, target=4},	-- Ravenous Brooch: Heal self for (0.4*attack) [UNVERFIED]
	[111]={type="nuke", damageATK=100, target="enemy-front"},	-- Sulfuric Emission: Damage frontmost row of enemies for (1*attack) [UNVERFIED]
	[112]={type="aura", plusDamageDealtATK=30, target="friend-surround", duration=3},	-- Gnashing Chompers: Mod damage done of closest allies by (0.3*attack) for 3 rounds [UNVERFIED] #Bug/#Workaround: ignored ineffective Effect.flags EXTRA_INITIAL_PERIOD
	[113]={type="nuke", damageATK=120, target="cone"},	-- Secutor's Judgment: Damage closest cone of enemies for (1.2*attack) [UNVERFIED]
	[114]={type="heal", healATK=100, target=4},	-- Reconstruction: Heal self for (1*attack) [UNVERFIED] #Bug/#Workaround: ignored incorrect Effect.Type
	[115]={type="nuke", damageATK=70, target="cleave"},	-- Dynamic Fist: Damage closest enemies for (0.7*attack) [UNVERFIED]
	[116]={type="nuke", damageATK=120, target=0},	-- Dreaming Charge: Damage closest enemy for (1.2*attack) [VERIFIED]
	[117]={type="nuke", damageATK=40, target="enemy-front"},	-- Swift Slash: Damage frontmost row of enemies for (0.4*attack) [VERIFIED]
	[118]={type="nuke", damageATK=200, target=1, firstTurn=4},	-- Mischievous Blast: Damage furthest enemy for (2*attack) [VERIFIED]
	[119]={type="nuke", damageATK=100, target="cone"},	-- Corrosive Thrust: Damage closest cone of enemies for (1*attack) [VERIFIED]
	[120]={type="aura", modDamageDealt=50, target="random-enemy", duration=2},	-- Goading Motivation: Mod damage done of random follower by 50% for 2 rounds [VERIFIED]
	[121]={type="aura", modDamageDealt=-50, target="all-enemies", duration=1},	-- Mesmeric Dust: Mod damage done of all enemies by -50% for 1 rounds [VERIFIED]
	[122]={type="aura", damageATK=30, target="random-enemy", duration=1, period=3, noFirstTick=true},	-- Humorous Flame: Damage (tick) random encounter for (0.3*attack) each subsequent 3rd round for 0 rounds [VERIFIED] #Bug/#Workaround: ignored ineffective Spell.Duration and Effect.Period
	[123]={type="heal", healATK=30, target="friend-front-soft"},	-- Healing Winds: Heal frontmost row of allies for (0.3*attack) [VERIFIED]
	[124]={type="nuke", damageATK=60, target="cleave"},	-- Kick: Damage closest enemies for (0.6*attack) [VERIFIED]
	[125]={
		[1]={type="nuke", damageATK=60, target="random-enemy"},	-- Deranged Gouge: Damage random follower for (0.6*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-50, target="random-enemy", duration=1},	-- Deranged Gouge: Mod damage done of random follower by -50% for 1 rounds [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Target and Effect.Period
	},
	[126]={type="heal", healATK=20, target="friend-front-soft"},	-- Possessive Healing: Heal frontmost row of allies for (0.2*attack) [VERIFIED]
	[127]={type="nuke", damageATK=60, target="enemy-front"},	-- Nibble: Damage frontmost row of enemies for (0.6*attack) [VERIFIED]
	[128]={type="nuke", damageATK=75, target="enemy-back"},	-- Regurgitate: Damage backmost row of enemies for (0.75*attack) [VERIFIED]
	[129]={
		[1]={type="heal", healATK=30, target="all-allies"},	-- Queen's Command: Heal all allies for (0.3*attack) [UNUSED]
		[2]={type="aura", modDamageDealt=50, target="all-allies", duration=1},	-- Queen's Command: Mod damage done of all allies by 50% for 1 rounds [UNUSED] #Bug/#Workaround: ignored ineffective Effect.Period
	},
	[130]={type="aura", thornsATK=100, target=4, duration=3},	-- Carapace Thorns: Damage attacker of self for (1*attack) for 3 rounds [VERIFIED]
	[131]={type="nuke", damageATK=150, target="enemy-back"},	-- Arcane Antlers: Damage backmost row of enemies for (1.5*attack) [VERIFIED]
	[132]={
		[1]={type="nuke", damageATK=50, target="enemy-front"},	-- Arbor Eruption: Damage frontmost row of enemies for (0.5*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-25, target="enemy-front", duration=1},	-- Arbor Eruption: Mod damage done of frontmost row of enemies by -25% for 1 rounds [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Period
	},
	[133]={
		[1]={type="nuke", damageATK=100, target="enemy-back"},	-- Hidden Power: Damage backmost row of enemies for (1*attack) [VERIFIED]
		[2]={type="heal", healATK=75, target=4},	-- Hidden Power: Heal self for (0.75*attack) [VERIFIED]
	},
	[134]={type="aura", modDamageTaken=25, target="all-enemies", duration=2},	-- Curse of the Dark Forest: Mod damage taken of all enemies by 25% for 2 rounds [VERIFIED]
	[135]={type="nuke", damageATK=300, target="enemy-back"},	-- Fires of Domination: Damage backmost row of enemies for (3*attack) [VERIFIED]
	[136]={type="aura", damageATK=150, target=0, duration=4, period=3, noFirstTick=true},	-- Searing Jaws: Damage (tick) closest enemy for (1.5*attack) each subsequent 3rd round for 3 rounds [UNVERFIED]
	[137]={type="aura", modDamageDealt=25, target=4, duration=2},	-- Hearty Shout: Mod damage done of self by 25% for 2 rounds [UNVERFIED]
	[138]={type="nuke", damageATK=30, target="cleave"},	-- Tail lash: Damage closest enemies for (0.3*attack) [VERIFIED]
	[139]={type="nuke", damageATK=400, target="enemy-back", firstTurn=6},	-- Hunger Frenzy: Damage backmost row of enemies for (4*attack) [VERIFIED]
	[140]={
		[1]={type="nuke", damageATK=60, target="enemy-back"},	-- Fan of Knives: Damage backmost row of enemies for (0.6*attack) [UNVERFIED]
		[2]={type="aura", modDamageDealt=-10, target="enemy-back", duration=2},	-- Fan of Knives: Mod damage done of backmost row of enemies by -10% for 2 rounds [UNVERFIED]
	},
	[141]={type="aura", modDamageTaken=-50, target="all-allies", duration=2},	-- Herd Immunity: Mod damage taken of all allies by -50% for 2 rounds [VERIFIED]
	[142]={type="heal", healATK=70, target=3},	-- Arcane Restoration: Heal closest cone of allies for (0.7*attack) [UNUSED]
	[143]={type="aura", modDamageDealt=25, target=4, duration=2},	-- Arrogant Boast: Mod damage done of self by 25% for 2 rounds [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Period
	[144]={type="aura", modDamageTaken=-75, target="all-other-allies", duration=2, firstTurn=4},	-- Ardent Defense: Mod damage taken of all-other allies by -75% for 2 rounds [VERIFIED]
	[145]={type="nuke", damageATK=75, target=0},	-- Shield Bash: Damage closest enemy for (0.75*attack) [VERIFIED]
	[146]={type="nuke", damageATK=75, target=1},	-- Dark Javelin: Damage furthest enemy for (0.75*attack) [VERIFIED]
	[147]={type="aura", modDamageTaken=-50, target="all-other-allies", duration=2},	-- Close Ranks: Mod damage taken of all-other allies by -50% for 2 rounds [VERIFIED]
	[148]={type="heal", healATK=125, target="friend-front-soft"},	-- Divine Maintenance: Heal frontmost row of allies for (1.25*attack) [VERIFIED]
	[149]={type="nuke", damageATK=75, target="enemy-front"},	-- Phalynx Slash: Damage frontmost row of enemies for (0.75*attack) [VERIFIED]
	[150]={type="nuke", damageATK=50, target="cone"},	-- Crashing Claws: Damage closest cone of enemies for (0.5*attack) [VERIFIED]
	[151]={type="nuke", damageATK=20, target=0},	-- Dive Bomb: Damage closest enemy for (0.2*attack) [VERIFIED]
	[152]={firstTurn=5,
		[1]={type="heal", healATK=200, target="all-other-allies"},	-- Anima Wave: Heal all-other allies for (2*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=50, target="all-other-allies", duration=1},	-- Anima Wave: Mod damage done of all-other allies by 50% for 1 rounds [VERIFIED]
	},
	[153]={type="nuke", damageATK=75, target="cone"},	-- Forbidden Research: Damage closest cone of enemies for (0.75*attack) [VERIFIED]
	[154]={type="aura", thornsATK=100, target=4, duration=3},	-- Stolen Wards: Damage attacker of self for (1*attack) for 3 rounds [VERIFIED]
	[155]={type="aura", modDamageDealt=-75, target="all-enemies", duration=1},	-- Concussive Roar: Mod damage done of all enemies by -75% for 1 rounds [VERIFIED]
	[156]={type="aura", modDamageTaken=40, target="all-enemies", duration=2},	-- Cursed Knowledge: Mod damage taken of all enemies by 40% for 2 rounds [VERIFIED]
	[157]={type="nuke", damageATK=80, target="cleave"},	-- Frantic Flap: Damage closest enemies for (0.8*attack) [VERIFIED]
	[158]={type="nuke", damageATK=300, target="enemy-back", firstTurn=3},	-- Explosion of Dark Knowledge: Damage backmost row of enemies for (3*attack) [VERIFIED]
	[159]={type="aura", modDamageDealt=-25, target="all-enemies", duration=2},	-- Proclamation of Doubt: Mod damage done of all enemies by -25% for 2 rounds [VERIFIED]
	[160]={type="nuke", damageATK=200, target="all-enemies"},	-- Seismic Slam: Damage all enemies for (2*attack) [UNVERFIED]
	[161]={
		[1]={type="heal", healATK=100, target="all-allies"},	-- Dark Command: Heal all allies for (1*attack) [UNVERFIED]
		[2]={type="aura", modDamageDealt=25, target="all-allies", duration=1},	-- Dark Command: Mod damage done of all allies by 25% for 1 rounds [UNVERFIED]
	},
	[162]={type="aura", modDamageDealt=-50, target="all-enemies", duration=2},	-- Curse of Darkness: Mod damage done of all enemies by -50% for 2 rounds [UNVERFIED]
	[163]={type="nuke", damageATK=400, target="all-enemies", firstTurn=6},	-- Wave of Conviction: Damage all enemies for (4*attack) [UNVERFIED]
	[164]={type="aura", damageATK=200, target="cone", duration=4, period=3, nore=true},	-- Dark Flame: Damage (tick) closest cone of enemies for (2*attack) immediately and each subsequent 3rd round for 3 rounds [VERIFIED]
	[165]={type="nuke", damageATK=300, target=0},	-- Winged Assault: Damage closest enemy for (3*attack) [VERIFIED]
	[166]={
		[1]={type="nuke", damageATK=100, target="random-ally"},	-- Leeching Bite: Damage random encounter for (1*attack) [VERIFIED]
		[2]={type="heal", healATK=50, target=4},	-- Leeching Bite: Heal self for (0.5*attack) [VERIFIED]
	},
	[167]={type="nuke", damageATK=150, target=1},	-- Razor Shards: Damage furthest enemy for (1.5*attack) [VERIFIED]
	[168]={type="aura", modDamageDealt=-50, target=0, duration=2},	-- Howl from Beyond: Mod damage done of closest enemy by -50% for 2 rounds [VERIFIED]
	[169]={
		[1]={type="nuke", damageATK=65, target=0},	-- Consuming Strike: Damage closest enemy for (0.65*attack) [VERIFIED]
		[2]={type="aura", damageATK=50, target=0, duration=4, period=3, nore=true},	-- Consuming Strike: Damage (tick) closest enemy for (0.5*attack) immediately and each subsequent 3rd round for 3 rounds [VERIFIED] To-do: test nore=true
	},
	[170]={type="nuke", damageATK=60, target="enemy-front"},	-- Stone Bash: Damage frontmost row of enemies for (0.6*attack) [VERIFIED]
	[171]={type="nuke", damageATK=100, target=1},	-- Pitched Boulder: Damage furthest enemy for (1*attack) [VERIFIED]
	[172]={firstTurn=3,
		[1]={type="nuke", damageATK=20, target="enemy-front"},	-- Viscous Slash: Damage frontmost row of enemies for (0.2*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-50, target="enemy-front", duration=1},	-- Viscous Slash: Mod damage done of frontmost row of enemies by -50% for 1 rounds [VERIFIED]
	},
	[173]={
		[1]={type="nuke", damageATK=75, target=1},	-- Icy Blast: Damage furthest enemy for (0.75*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-25, target=1, duration=2},	-- Icy Blast: Mod damage done of furthest enemy by -25% for 2 rounds [VERIFIED]
	},
	[174]={type="aura", thornsATK=40, target=4, duration=3},	-- Polished Ice Barrier: Damage attacker of self for (0.4*attack) for 3 rounds [VERIFIED]
	[175]={type="nuke", damageATK=120, target="random-all"},	-- Lash Out: Damage random target for (1.2*attack) [VERIFIED]
	[176]={type="aura", modDamageTaken=25, target="all-enemies", duration=1},	-- Arrogant Denial: Mod damage taken of all enemies by 25% for 1 rounds [VERIFIED]
	[177]={type="nuke", damageATK=50, target=0},	-- Shoulder Charge: Damage closest enemy for (0.5*attack) [VERIFIED]
	[178]={
		[1]={type="nuke", damageATK=100, target=1},	-- Draw Anima: Damage furthest enemy for (1*attack) [VERIFIED]
		[2]={type="heal", healATK=50, target=4},	-- Draw Anima: Heal self for (0.5*attack) [VERIFIED]
	},
	[179]={
		[1]={type="heal", healATK=100, target="all-allies"},	-- Medical Advice: Heal all allies for (1*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=50, target="all-allies", duration=2},	-- Medical Advice: Mod damage done of all allies by 50% for 2 rounds [VERIFIED]
	},
	[180]={type="nuke", damageATK=75, target="random-enemy"},	-- Mental Assault: Damage random follower for (0.75*attack) [VERIFIED]
	[181]={type="nuke", damageATK=150, target="enemy-back", firstTurn=6},	-- Anima Blast: Damage backmost row of enemies for (1.5*attack) [VERIFIED]
	[182]={type="aura", modDamageDealt=-50, target="all-enemies", duration=2},	-- Deceptive Practice: Mod damage done of all enemies by -50% for 2 rounds [VERIFIED]
	[183]={type="nuke", damageATK=50, target="enemy-front"},	-- Shadow Swipe: Damage frontmost row of enemies for (0.5*attack) [VERIFIED]
	[184]={type="nuke", damageATK=75, target="cone"},	-- Anima Lash: Damage closest cone of enemies for (0.75*attack) [VERIFIED]
	[185]={type="nuke", damageATK=100, target="all-enemies"},	-- Temper Tantrum: Damage all enemies for (1*attack) [UNVERFIED]
	[186]={type="nuke", damageATK=200, target="enemy-front", firstTurn=5},	-- Feral Rage: Damage frontmost row of enemies for (2*attack) [VERIFIED]
	[187]={type="aura", damageATK=50, target="all-enemies", duration=3, period=2, nore=true},	-- Toxic Miasma: Damage (tick) all enemies for (0.5*attack) immediately and each subsequent 2nd round for 2 rounds [UNVERFIED]
	[188]={
		[1]={type="nuke", damageATK=50, target=0},	-- Angry Smash: Damage closest enemy for (0.5*attack) [UNVERFIED]
		[2]={type="aura", modDamageDealt=-50, target=0, duration=1},	-- Angry Smash: Mod damage done of closest enemy by -50% for 1 rounds [UNVERFIED]
	},
	[189]={type="nuke", damageATK=200, target=0},	-- Angry Bash: Damage closest enemy for (2*attack) [UNVERFIED]
	[190]={type="nuke", damageATK=150, target="enemy-front"},	-- Anima Wave: Damage frontmost row of enemies for (1.5*attack) [UNVERFIED]
	[191]={
		[1]={type="nuke", damageATK=100, target="all-enemies"},	-- Toxic Dispersal: Damage all enemies for (1*attack) [UNVERFIED] #Bug/#Workaround: ignored incorrect Effect.Type
		[2]={type="heal", healATK=100, target="all-allies"},	-- Toxic Dispersal: Heal all allies for (1*attack) [UNVERFIED] #Bug/#Workaround: ignored incorrect Effect.Type
	},
	[192]={type="nuke", damageATK=160, target=1},	-- Shadow Bolt: Damage furthest enemy for (1.6*attack) [UNVERFIED]
	[193]={
		[1]={type="nuke", damageATK=300, target="enemy-front"},	-- Flesh Eruption: Damage frontmost row of enemies for (3*attack) [UNVERFIED]
		[2]={type="nuke", damageATK=50, target=4},	-- Flesh Eruption: Damage self for (0.5*attack) [UNVERFIED]
	},
	[194]={
		[1]={type="aura", plusDamageDealtATK=40, target=3, duration=2},	-- Potentiated Power: Mod damage done of closest ally by (0.4*attack) for 2 rounds [UNVERFIED]
		[2]={type="aura", modDamageTaken=-20, target=3, duration=2},	-- Potentiated Power: Mod damage taken of closest ally by -20% for 2 rounds [UNVERFIED]
		[3]={type="nuke", damageATK=20, target=4},	-- Potentiated Power: Damage self for (0.2*attack) [UNVERFIED]
	},
	[195]={type="aura", damageATK=80, target="cone", duration=3, nore=true},	-- Creeping Chill: Damage (tick) closest cone of enemies for (0.8*attack) immediately and each subsequent round for 2 rounds [UNVERFIED]
	[196]={
		[1]={type="nuke", damageATK=120, target=0},	-- Hail of Blades: Damage closest enemy for (1.2*attack) [UNVERFIED]
		[2]={type="nuke", damageATK=90, target=0},	-- Hail of Blades: Damage closest enemy for (0.9*attack) [UNVERFIED]
		[3]={type="nuke", damageATK=60, target=0},	-- Hail of Blades: Damage closest enemy for (0.6*attack) [UNVERFIED]
		[4]={type="nuke", damageATK=30, target=0},	-- Hail of Blades: Damage closest enemy for (0.3*attack) [UNVERFIED]
	},
	[197]={type="heal", healATK=55, target="friend-surround"},	-- Reassembly: Heal closest allies for (0.55*attack) [UNVERFIED]
	[198]={
		[1]={type="aura", plusDamageTakenATK=-60, target=4, duration=2},	-- Bone Shield: Mod damage taken of self by (-0.6*attack) for 2 rounds [UNVERFIED]
		[2]={type="aura", thornsATK=60, target=4, duration=2},	-- Bone Shield: Damage attacker of self for (0.6*attack) for 2 rounds [UNVERFIED]
	},
	[199]={type="nuke", damageATK=100, target="enemy-front"},	-- Lumbering swing: Damage frontmost row of enemies for (1*attack) [VERIFIED]
	[200]={
		[1]={type="nuke", damageATK=100, target="enemy-front"},	-- Stunning Swipe: Damage frontmost row of enemies for (1*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-50, target="enemy-front", duration=1},	-- Stunning Swipe: Mod damage done of frontmost row of enemies by -50% for 1 rounds [VERIFIED]
	},
	[201]={type="nuke", damageATK=200, target="enemy-back"},	-- Monstrous Rage: Damage backmost row of enemies for (2*attack) [VERIFIED]
	[202]={type="taunt", target="all-enemies", duration=2},	-- Whirling Wall: Taunt all enemies for 2 rounds [VERIFIED]
	[203]={type="nuke", damageATK=100, target="enemy-front"},	-- Bitting Winds: Damage frontmost row of enemies for (1*attack) [VERIFIED]
	[204]={
		[1]={type="nuke", damageATK=150, target=0},	-- Death Blast: Damage closest enemy for (1.5*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-50, target=0, duration=2},	-- Death Blast: Mod damage done of closest enemy by -50% for 2 rounds [VERIFIED]
	},
	[205]={type="heal", healATK=75, target="friend-front-soft"},	-- Bone Dust: Heal frontmost row of allies for (0.75*attack) [VERIFIED]
	[206]={type="nuke", damageATK=150, target=0},	-- Abominable Kick: Damage closest enemy for (1.5*attack) [VERIFIED]
	[207]={type="nuke", damageATK=30, target=0},	-- Feral Lunge: Damage closest column of enemies for (0.3*attack) [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Target
	[208]={type="taunt", target="random-ally", duration=2},	-- Intimidating Roar: Taunt random encounter for 2 rounds [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Type and Effect.Target
	[209]={type="aura", modDamageDealt=50, target="random-ally", duration=1},	-- Ritual Fervor: Mod damage done of random encounter by 50% for 1 rounds [VERIFIED]
	[210]={type="nuke", damageATK=200, target="all-enemies"},	-- Waves of Death: Damage all enemies for (2*attack) [VERIFIED]
	[211]={type="nuke", damageATK=150, target="cone"},	-- Acidic Ejection: Damage closest cone of enemies for (1.5*attack) [VERIFIED]
	[212]={type="nuke", damageATK=200, target="random-all"},	-- Panic Attack: Damage random target for (2*attack) [VERIFIED]
	[213]={type="heal", healATK=100, target=3},	-- Heal the Flock: Heal closest cone of allies for (1*attack) [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Target
	[214]={type="nuke", damageATK=100, target="cone"},	-- Necrotic Lash: Damage closest cone of enemies for (1*attack) [VERIFIED]
	[215]={type="nuke", damageATK=300, target=0},	-- Slime Fist: Damage closest enemy for (3*attack) [VERIFIED]
	[216]={type="shroud", target=4, duration=2},	-- Threatening Hiss: Detaunt self for 2 rounds [VERIFIED]
	[217]={type="nuke", damageATK=200, target="enemy-back"},	-- Massacre: Damage backmost row of enemies for (2*attack) [VERIFIED]
	[218]={type="aura", modDamageTaken=-50, target=4, duration=2},	-- Ritual of Bone: Mod damage taken of self by -50% for 2 rounds [UNVERFIED]
	[219]={
		[1]={type="heal", healATK=200, target=3},	-- Necrotic Healing: Heal closest ally for (2*attack) [UNVERFIED]
		[2]={type="aura", modDamageTaken=-50, target=3, duration=2},	-- Necrotic Healing: Mod damage taken of closest ally by -50% for 2 rounds [UNVERFIED]
	},
	[220]={type="nuke", damageATK=100, target="enemy-front"},	-- Wild Slice: Damage frontmost row of enemies for (1*attack) [UNVERFIED]
	[221]={type="shroud", target=4, duration=2},	-- Burrow: Detaunt self for 2 rounds [UNVERFIED]
	[222]={
		[1]={type="nuke", damageATK=30, target=0},	-- Poisonous Bite: Damage closest enemy for (0.3*attack) [UNVERFIED]
		[2]={type="aura", damageATK=30, target=0, duration=3, period=2, nore=true},	-- Poisonous Bite: Damage (tick) closest enemy for (0.3*attack) immediately and each subsequent 2nd round for 2 rounds [UNVERFIED]
	},
	[223]={type="aura", damageATK=10, cATKa=60, cATKb=2, target="all-enemies", duration=11, noFirstTick=true},	-- Wave of Eternal Death: Damage (tick) all followers for (0.1*attack) each subsequent round for 10 rounds [VERIFIED]
	[224]={type="nuke", damageATK=50, target="enemy-front"},	-- Maw Wrought Slash: Damage frontmost row of enemies for (0.5*attack) [VERIFIED]
	[225]={type="nuke", damageATK=50, target="cone"},	-- Stream of Anguish: Damage closest cone of enemies for (0.5*attack) [VERIFIED]
	[226]={type="nuke", damageATK=50, target="cone"},	-- Thrust of the Maw: Damage closest cone of enemies for (0.5*attack) [VERIFIED]
	[227]={type="nuke", damagePerc=30, target="random-enemy"},	-- Bombardment of Dread: Damage random follower for 30% [VERIFIED]
	[228]={type="nuke", damageATK=1000, cATKa=500, cATKb=2, target="all-enemies", firstTurn=10},	-- Destruction: Damage all followers for (10*attack) [VERIFIED]
	[229]={type="aura", modDamageTaken=-50, target="random-ally", duration=2},	-- Mawsworn Ritual: Mod damage taken of random encounter by -50% for 2 rounds [VERIFIED]
	[230]={type="heal", healATK=50, cATKa=50, cATKb=2, target="all-allies"},	-- Faith in Domination: Heal all encounters for (0.5*attack) [VERIFIED]
	[231]={type="aura", modDamageTaken=100, target="random-enemy", duration=2},	-- Mawsworn Strength: Mod damage taken of random follower by 100% for 2 rounds [VERIFIED]
	[232]={type="aura", modDamageDealt=-50, target="random-enemy", duration=3},	-- Aura of Death: Mod damage done of random follower by -50% for 3 rounds [VERIFIED]
	[233]={type="nuke", damageATK=150, target=0},	-- Teeth of the Maw: Damage closest enemy for (1.5*attack) [VERIFIED]
	[234]={type="aura", modDamageDealt=50, target="random-ally", duration=2},	-- Power of Anguish: Mod damage done of random encounter by 50% for 2 rounds [VERIFIED]
	[235]={type="nuke", damageATK=50, target=1},	-- Vengence of the Mawsworn: Damage furthest enemy for (0.5*attack) [VERIFIED]
	[236]={type="aura", modDamageTaken=-50, target="all-allies", duration=2},	-- Empowered Minions: Mod damage taken of all allies by -50% for 2 rounds [VERIFIED]
	[237]={type="nuke", damageATK=50, target="enemy-front"},	-- Maw Swoop: Damage frontmost row of enemies for (0.5*attack) [VERIFIED]
	[238]={type="taunt", target="all-enemies", duration=2},	-- Death Shield: Taunt all enemies for 2 rounds [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Points and Effect.Flags
	[239]={type="nuke", damageATK=50, target="enemy-back"},	-- Beam of Doom: Damage backmost row of enemies for (0.5*attack) [VERIFIED]
	[240]={type="nuke", damageATK=25, target=0},	-- Spear of Dread: Damage closest column of enemies for (0.25*attack) [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Target
	[241]={
		[1]={type="nuke", damageATK=75, target=1},	-- Pain Spike: Damage furthest enemy for (0.75*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-50, target=1, duration=2},	-- Pain Spike: Mod damage done of furthest enemy by -50% for 2 rounds [VERIFIED]
	},
	[242]={
		[1]={type="heal", healATK=50, target=3},	-- Dark Healing: Heal closest ally for (0.5*attack) [VERIFIED]
		[2]={type="aura", modDamageTaken=75, target=3, duration=2},	-- Dark Healing: Mod damage taken of closest ally by 75% for 2 rounds [VERIFIED]
	},
	[243]={
		[1]={type="taunt", target="all-enemies", duration=2},	-- Baleful Stare: Taunt all enemies for 2 rounds [VERIFIED]
		[2]={type="aura", modDamageTaken=-50, target=4, duration=2},	-- Baleful Stare: Mod damage taken of self by -50% for 2 rounds [VERIFIED]
	},
	[244]={firstTurn=2,
		[1]={type="aura", plusDamageDealtATK=200, target=4, duration=2},	-- Meatball Mad!: Mod damage done of self by (2*attack) for 2 rounds [VERIFIED]
		[2]={type="aura", plusDamageTakenATK=30, target=4, duration=2},	-- Meatball Mad!: Mod damage taken of self by (0.3*attack) for 2 rounds [VERIFIED]
		[3]={type="nuke", damageATK=30, target=0},	-- Meatball Mad!: Damage closest enemy for (0.3*attack) [VERIFIED]
	},
	[245]={type="nuke", damageATK=120, target=0},	-- Crusader Strike: Damage closest enemy for (1.2*attack) [VERIFIED]
	[246]={type="nuke", damageATK=150, target=0},	-- Snarling Bite: Damage closest enemy for (1.5*attack) [VERIFIED]
	[247]={firstTurn=4,
		[1]={type="nuke", damageATK=10, target=0},	-- Skymane Strike: Damage closest enemy for (0.1*attack) [VERIFIED]
		[2]={type="heal", healATK=20, target=4},	-- Skymane Strike: Heal self for (0.2*attack) [VERIFIED]
	},
	[248]={
		[1]={type="nuke", damageATK=30, target=0},	-- Infectious Soulbite: Damage closest enemy for (0.3*attack) [VERIFIED]
		[2]={type="aura", damageATK=15, target=0, duration=5, noFirstTick=true},	-- Infectious Soulbite: Damage (tick) closest enemy for (0.15*attack) each subsequent round for 4 rounds [VERIFIED]
	},
	[249]={
		[1]={type="nuke", damageATK=60, target=0},	-- Shield Bash: Damage closest enemy for (0.6*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-50, target=0, duration=1},	-- Shield Bash: Mod damage done of closest enemy by -50% for 1 rounds [VERIFIED]
	},
	[250]={type="nuke", damageATK=80, target=1, firstTurn=4},	-- Thorned Slingshot: Damage furthest enemy for (0.8*attack) [VERIFIED]
	[251]={type="aura", modDamageDealt=-20, target="all-enemies", duration=2},	-- Doom of the Drust: Mod damage done of all enemies by -20% for 2 rounds [VERIFIED]
	[252]={
		[1]={type="nuke", damageATK=60, target="cleave"},	-- Viscous Sweep: Damage closest enemies for (0.6*attack) [VERIFIED]
		[2]={type="aura", modDamageTaken=25, target="cleave", duration=2},	-- Viscous Sweep: Mod damage taken of closest enemies by 25% for 2 rounds [VERIFIED]
	},
	[253]={type="nuke", damageATK=75, target="enemy-front"},	-- Drust Claws: Damage frontmost row of enemies for (0.75*attack) [VERIFIED]
	[254]={type="aura", thornsATK=100, target="all-other-allies", duration=3, firstTurn=3},	-- Drust Thorns: Damage attacker of all-other allies for (1*attack) for 3 rounds [VERIFIED]
	[255]={type="aura", modDamageTaken=-50, target=3, duration=1},	-- Defense of the Drust: Mod damage taken of closest ally by -50% for 1 rounds [VERIFIED]
	[256]={type="nuke", damageATK=100, target="cone"},	-- Drust Blast: Damage closest cone of enemies for (1*attack) [VERIFIED]
	[257]={type="shroud", target=4, duration=2},	-- Dread Roar: Detaunt self for 2 rounds [VERIFIED]
	[258]={
		[1]={type="nuke", damageATK=100, target=0},	-- Dark Gouge: Damage closest enemy for (1*attack) [VERIFIED]
		[2]={type="aura", damageATK=50, target=0, duration=4, period=3, nore=true},	-- Dark Gouge: Damage (tick) closest enemy for (0.5*attack) immediately and each subsequent 3rd round for 3 rounds [VERIFIED] To-do: test nore=true
	},
	[259]={type="aura", damageATK=30, target=0, duration=4, period=3, noFirstTick=true},	-- Anima Flame: Damage (tick) closest enemy for (0.3*attack) each subsequent 3rd round for 3 rounds [VERIFIED]
	[260]={type="nuke", damageATK=150, target=1},	-- Anima Burst: Damage furthest enemy for (1.5*attack) [VERIFIED]
	[261]={type="aura", modDamageDealt=50, target=3, duration=2},	-- Surgical Advances: Mod damage done of closest ally by 50% for 2 rounds [VERIFIED]
	[262]={type="nuke", damageATK=100, target="enemy-front"},	-- Putrid Stomp: Damage frontmost row of enemies for (1*attack) [VERIFIED]
	[263]={type="nuke", damageATK=100, target="cone"},	-- Acidic Vomit: Damage closest cone of enemies for (1*attack) [VERIFIED]
	[264]={type="nuke", damageATK=300, target=1},	-- Meat Hook: Damage furthest enemy for (3*attack) [VERIFIED]
	[265]={type="nuke", damageATK=100, target=0},	-- Toxic Claws: Damage closest column of enemies for (1*attack) [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Target
	[266]={type="nuke", damageATK=1000, target=0},	-- Colossal Strike: Damage closest enemy for (10*attack) [VERIFIED]
	[267]={type="nuke", damageATK=150, target=1},	-- Acidic Volley: Damage furthest enemy for (1.5*attack) [VERIFIED]
	[268]={type="aura", modDamageDealt=-30, target="enemy-front", duration=3},	-- Acidic Spray: Mod damage done of frontmost row of enemies by -30% for 3 rounds [VERIFIED]
	[269]={type="nuke", damageATK=120, target="enemy-front"},	-- Acidic Stomp: Damage frontmost row of enemies for (1.2*attack) [VERIFIED]
	[270]={type="aura", modDamageDealt=-50, target=0, duration=2},	-- Spidersong Webbing: Mod damage done of closest enemy by -50% for 2 rounds [VERIFIED]
	[271]={type="aura", damageATK=100, target=1, duration=4, noFirstTick=true},	-- Ambush: Damage (tick) furthest enemy for (1*attack) each subsequent round for 3 rounds [VERIFIED]
	[272]={type="nuke", damageATK=150, target=1},	-- Soulfrost Shard: Damage furthest enemy for (1.5*attack) [VERIFIED]
	[273]={type="aura", modDamageDealt=-50, target=0, duration=1},	-- Ritual Curse: Mod damage done of closest enemy by -50% for 1 rounds [UNUSED]
	[274]={type="nuke", damageATK=120, target="enemy-front"},	-- Stomp Flesh: Damage frontmost row of enemies for (1.2*attack) [VERIFIED]
	[275]={type="aura", modDamageDealt=75, target=3, duration=2},	-- Necromantic Infusion: Mod damage done of closest ally by 75% for 2 rounds [VERIFIED]
	[276]={
		[1]={type="nuke", damageATK=25, target=1},	-- Rot Volley: Damage furthest enemy for (0.25*attack) [VERIFIED]
		[2]={type="aura", damageATK=50, target=1, duration=4, period=3, nore=true},	-- Rot Volley: Damage (tick) furthest enemy for (0.5*attack) immediately and each subsequent 3rd round for 3 rounds [VERIFIED] To-do: test nore=true 
	},
	[277]={type="aura", modDamageDealt=100, target=4, duration=2},	-- Seething Rage: Mod damage done of self by 100% for 2 rounds [VERIFIED]
	[278]={type="aura", modDamageTaken=50, target=1, duration=2},	-- Memory Displacement: Mod damage taken of furthest enemy by 50% for 2 rounds [VERIFIED]
	[279]={type="nuke", damageATK=50, target="enemy-back"},	-- Painful Recollection: Damage backmost row of enemies for (0.5*attack) [VERIFIED]
	[280]={type="nuke", damageATK=250, target="enemy-front"},	-- Quills: Damage frontmost row of enemies for (2.5*attack) [VERIFIED]
	[281]={type="nuke", damageATK=150, target=1},	-- Anima Spit: Damage furthest enemy for (1.5*attack) [VERIFIED]
	[282]={type="nuke", damageATK=1000, target=0, firstTurn=5},	-- Charged Javelin: Damage closest enemy for (10*attack) [VERIFIED]
	[283]={type="nuke", damageATK=75, target=0},	-- Anima Claws: Damage closest column of enemies for (0.75*attack) [VERIFIED] #Bug/#Workaround: ignored ineffective Effect.Target
	[284]={type="aura", modDamageTaken=-50, target="all-other-allies", duration=1},	-- Empyreal Reflexes: Mod damage taken of all-other allies by -50% for 1 rounds [VERIFIED]
	[285]={type="aura", modDamageTaken=50, target="all-enemies", duration=2, firstTurn=4},	-- Forsworn's Wrath: Mod damage taken of all enemies by 50% for 2 rounds [VERIFIED]
	[286]={type="aura", modDamageDealt=50, target=3, duration=2},	-- CHARGE!: Mod damage done of closest ally by 50% for 2 rounds [VERIFIED]
	[287]={type="aura", modDamageTaken=-50, target=4, duration=1},	-- Elusive Duelist: Mod damage taken of self by -50% for 1 rounds [VERIFIED]
	[288]={type="nuke", damageATK=60, target="enemy-back"},	-- Stone Swipe: Damage backmost row of enemies for (0.6*attack) [VERIFIED]
	[289]={type="aura", damageATK=100, target=1, duration=4, period=3, nore=true},	-- Toxic Bolt: Damage (tick) furthest enemy for (1*attack) immediately and each subsequent 3rd round for 3 rounds [VERIFIED]
	[290]={type="nuke", damageATK=150, target=1},	-- Ashen Bolt: Damage furthest enemy for (1.5*attack) [VERIFIED]
	[291]={type="nuke", damageATK=100, target="enemy-front"},	-- Ashen Blast: Damage frontmost row of enemies for (1*attack) [VERIFIED]
	[292]={
		[1]={type="aura", modDamageTaken=50, target=0, duration=2},	-- Master's Surprise: Mod damage taken of closest enemy by 50% for 2 rounds [VERIFIED]
		[2]={type="nuke", damageATK=75, target=0},	-- Master's Surprise: Damage closest enemy for (0.75*attack) [VERIFIED]
	},
	[293]={type="nuke", damageATK=60, target="enemy-front"},	-- Stone Crush: Damage frontmost row of enemies for (0.6*attack) [UNUSED]
	[294]={type="nuke", damageATK=200, target=0},	-- Stone Bash: Damage closest enemy for (2*attack) [VERIFIED]
	[295]={type="aura", modDamageTaken=50, target=0, duration=2},	-- Dreadful Exhaust: Mod damage taken of closest enemy by 50% for 2 rounds [VERIFIED]
	[296]={type="nuke", damageATK=100, target="enemy-back", firstTurn=3},	-- Death Bolt: Damage backmost row of enemies for (1*attack) [VERIFIED]
	[297]={
		[1]={type="nuke", damageATK=100, target=1},	-- Anima Thirst: Damage furthest enemy for (1*attack) [VERIFIED]
		[2]={type="heal", healATK=30, target=4},	-- Anima Thirst: Heal self for (0.3*attack) [VERIFIED]
	},
	[298]={
		[1]={type="nuke", damageATK=100, target="random-ally"},	-- Anima Leech: Damage random encounter for (1*attack) [VERIFIED]
		[2]={type="heal", healATK=30, target=4},	-- Anima Leech: Heal self for (0.3*attack) [VERIFIED]
	},
	[299]={type="nuke", damageATK=200, target=1},	-- Plague Blast: Damage furthest enemy for (2*attack) [UNVERFIED]
	[300]={type="aura", damageATK=5, cATKa=10, cATKb=2, target="all-enemies", duration=4, noFirstTick=true},	-- Wave of Eternal Death: Damage (tick) all followers for (0.05*attack) each subsequent round for 3 rounds [VERIFIED] To-do: test stacking ticks from the same spell behaviour
	[301]={type="nuke", damagePerc=10, target="random-enemy"},	-- Bombardment of Dread: Damage random follower for 10% [VERIFIED]
	[302]={
		[1]={type="nuke", damageATK=20, target="all-enemies"},	-- Bramble Trap: Damage all enemies for (0.2*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-20, target="all-enemies", duration=1},	-- Bramble Trap: Mod damage done of all enemies by -20% for 1 rounds [VERIFIED]
	},
	[303]={type="nuke", damageATK=25, target="enemy-back"},	-- Plague Song: Damage backmost row of enemies for (0.25*attack) [UNVERFIED]
	[305]={type="nuke", damageATK=120, target="enemy-back"},	-- Roots of Submission: Damage backmost row of enemies for (1.2*attack) [VERIFIED]
	[306]={
		[1]={type="aura", plusDamageDealtATK=40, target=3, duration=3},	-- Arcane Empowerment: Mod damage done of closest ally by (0.4*attack) for 3 rounds [VERIFIED]
		[2]={type="aura", modMaxHPATK=60, target=3, duration=3},	-- Arcane Empowerment: Mod max health of closest ally by (0.6*attack) for 3 rounds [VERIFIED]
	},
	[307]={type="nuke", damageATK=160, target="cone"},	-- Fist of Nature: Damage closest cone of enemies for (1.6*attack) [VERIFIED]
	[308]={type="nuke", damageATK=350, target=1, firstTurn=3},	-- Spore of Doom: Damage furthest enemy for (3.5*attack) [VERIFIED]
	[309]={
		[1]={type="heal", healATK=200, target="all-allies"},	-- Threads of Fate: Heal all allies for (2*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=30, target="all-allies", duration=1},	-- Threads of Fate: Mod damage done of all allies by 30% for 1 rounds [VERIFIED]
	},
	[310]={
		[1]={type="nuke", damageATK=140, target=0},	-- Axe of Determination: Damage closest enemy for (1.4*attack) [UNVERFIED]
		[2]={type="aura", modDamageDealt=20, target=4, duration=2},	-- Axe of Determination: Mod damage done of self by 20% for 2 rounds [UNVERFIED]
	},
	[311]={
		[1]={type="heal", healATK=120, target=3},	-- Wings of Mending: Heal closest ally for (1.2*attack) [UNVERFIED]
		[2]={type="aura", modMaxHPATK=40, target=3, duration=2},	-- Wings of Mending: Mod max health of closest ally by (0.4*attack) for 2 rounds [UNVERFIED]
	},
	[312]={type="nuke", damageATK=180, target="cone"},	-- Panoptic Beam: Damage closest cone of enemies for (1.8*attack) [UNVERFIED]
	[313]={type="heal", healATK=70, target="all-allies"},	-- Spirit's Guidance: Heal all allies for (0.7*attack) [UNVERFIED]
	[314]={
		[1]={type="heal", healATK=130, target=3},	-- Purifying Light: Heal closest ally for (1.3*attack) [VERIFIED]
		[2]={type="aura", plusDamageDealtATK=50, target=3, duration=2},	-- Purifying Light: Mod damage done of closest ally by (0.5*attack) for 2 rounds [VERIFIED]
	},
	[315]={
		[1]={type="nuke", damageATK=150, target=1},	-- Resounding Message: Damage furthest enemy for (1.5*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=-30, target=1, duration=2},	-- Resounding Message: Mod damage done of furthest enemy by -30% for 2 rounds [VERIFIED]
	},
	[316]={
		[1]={type="nuke", damageATK=100, target=0},	-- Self Replication: Damage closest enemy for (1*attack) [UNVERFIED]
		[2]={type="heal", healATK=30, target=4},	-- Self Replication: Heal self for (0.3*attack) [UNVERFIED]
	},
	[317]={
		[1]={type="nuke", damageATK=150, target="enemy-front"},	-- Shocking Fist: Damage frontmost row of enemies for (1.5*attack) [UNVERFIED]
		[2]={type="aura", plusDamageTakenATK=30, target="enemy-front", duration=1},	-- Shocking Fist: Mod damage taken of frontmost row of enemies by (0.3*attack) for 1 rounds [UNVERFIED]
	},
	[318]={type="aura", plusDamageDealtATK=50, target="all-allies", duration=3},	-- Inspiring Howl: Mod damage done of all allies by (0.5*attack) for 3 rounds [UNVERFIED]
	[319]={
		[1]={type="nuke", damageATK=80, target="enemy-front"},	-- Shattering Blows: Damage frontmost row of enemies for (0.8*attack) [UNVERFIED]
		[2]={type="aura", damageATK=50, target="enemy-front", duration=4, noFirstTick=true},	-- Shattering Blows: Damage (tick) frontmost row of enemies for (0.5*attack) each subsequent round for 3 rounds [UNVERFIED]
	},
	[320]={type="nuke", damageATK=100, target="enemy-back"},	-- Hailstorm: Damage backmost row of enemies for (1*attack) [UNVERFIED]
	[321]={type="heal", healATK=200, target=3},	-- Adjustment: Heal closest ally for (2*attack) [VERIFIED]
	[322]={
		[1]={type="nuke", damageATK=80, target=0},	-- Balance In All Things: Damage closest enemy for (0.8*attack) [UNVERFIED]
		[2]={type="heal", healATK=80, target=4},	-- Balance In All Things: Heal self for (0.8*attack) [UNVERFIED]
		[3]={type="aura", modMaxHPATK=80, target=4, duration=1},	-- Balance In All Things: Mod max health of self by (0.8*attack) for 1 rounds [UNVERFIED]
	},
	[323]={
		[1]={type="nuke", damageATK=40, target="enemy-back"},	-- Anima Shatter: Damage backmost row of enemies for (0.4*attack) [UNVERFIED]
		[2]={type="aura", modDamageDealt=-10, target="enemy-back", duration=2},	-- Anima Shatter: Mod damage done of backmost row of enemies by -10% for 2 rounds [UNVERFIED]
	},
	[324]={type="heal", healATK=120, target="friend-surround"},	-- Protective Parasol: Heal closest allies for (1.2*attack) [UNVERFIED]
	[325]={type="aura", modDamageDealt=60, target="friend-surround", duration=2},	-- Vision of Beauty: Mod damage done of closest allies by 60% for 2 rounds [UNVERFIED]
	[326]={type="nuke", damageATK=25, target="cleave"},	-- Shiftless Smash: Damage closest enemies for (0.25*attack) [VERIFIED]
	[327]={type="aura", plusDamageDealtATK=20, target="all-other-allies", duration=3},	-- Inspirational Teachings: Mod damage done of all-other allies by (0.2*attack) for 3 rounds [VERIFIED]
	[328]={type="nuke", damageATK=30, target=0},	-- Applied Lesson: Damage closest enemy for (0.3*attack) [VERIFIED]
	[329]={type="aura", modDamageTaken=-50, target=4, duration=3},	-- Muscle Up: Mod damage taken of self by -50% for 3 rounds [VERIFIED]
	[330]={type="aura", plusDamageDealtATK=20, target="all-allies", duration=2},	-- Oversight: Mod damage done of all allies by (0.2*attack) for 2 rounds [VERIFIED]
	[331]={type="aura", plusDamageDealtATK=20, target="all-other-allies", duration=3},	-- Supporting Fire: Mod damage done of all-other allies by (0.2*attack) for 3 rounds [VERIFIED]
	[332]={type="nuke", damageATK=150, target=1},	-- Emptied Mug: Damage furthest enemy for (1.5*attack) [VERIFIED]
	[333]={type="aura", plusDamageDealtATK=40, target=4, duration=3},	-- Overload: Mod damage done of self by (0.4*attack) for 3 rounds [VERIFIED]
	[334]={type="nuke", damageATK=90, target=0},	-- Hefty Package: Damage closest enemy for (0.9*attack) [VERIFIED]
	[335]={type="nuke", damageATK=40, target="enemy-back"},	-- Errant Package: Damage backmost row of enemies for (0.4*attack) [VERIFIED]
	[336]={type="heal", healATK=80, target=3},	-- Evidence of Wrongdoing: Heal closest ally for (0.8*attack) [VERIFIED]
	[337]={
		[1]={type="nuke", damageATK=200, target=1},	-- Wavebender's Tide: Damage furthest enemy for (2*attack) [VERIFIED]
		[2]={type="aura", damageATK=40, target=1, duration=4, noFirstTick=true},	-- Wavebender's Tide: Damage (tick) furthest enemy for (0.4*attack) each subsequent round for 3 rounds [VERIFIED]
	},
	[338]={type="nuke", damageATK=50, target=0},	-- Scallywag Slash: Damage closest enemy for (0.5*attack) [VERIFIED]
	[339]={type="nuke", damageATK=120, target="all-enemies", firstTurn=3},	-- Cannon Barrage: Damage all enemies for (1.2*attack) [VERIFIED]
	[340]={type="nuke", damageATK=60, target=1},	-- Tainted Bite: Damage furthest enemy for (0.6*attack) [UNUSED]
	[341]={
		[1]={type="nuke", damageATK=120, target=1},	-- Tainted Bite: Damage furthest enemy for (1.2*attack) [VERIFIED]
		[2]={type="aura", plusDamageTakenATK=20, target=1, duration=3},	-- Tainted Bite: Mod damage taken of furthest enemy by (0.2*attack) for 3 rounds [VERIFIED]
	},
	[342]={
		[1]={type="nuke", damageATK=100, target=0},	-- Regurgitated Meal: Damage closest enemy for (1*attack) [VERIFIED]
		[2]={type="aura", plusDamageDealtATK=-70, target=0, duration=1},	-- Regurgitated Meal: Mod damage done of closest enemy by (-0.7*attack) for 1 rounds [VERIFIED]
	},
	[343]={
		[1]={type="nuke", damageATK=80, target="enemy-front"},	-- Sharptooth Snarl: Damage frontmost row of enemies for (0.8*attack) [VERIFIED]
		[2]={type="aura", modDamageDealt=20, target=4, duration=1},	-- Sharptooth Snarl: Mod damage done of self by 20% for 1 rounds [VERIFIED]
	},
	[344]={type="nuke", damageATK=30, target="all-enemies"},	-- Razorwing Buffet: Damage all enemies for (0.3*attack) [VERIFIED]
	[345]={type="aura", plusDamageTakenATK=-30, target="all-allies", duration=3},	-- Protective Wings: Mod damage taken of all allies by (-0.3*attack) for 3 rounds [VERIFIED]
	[346]={
		[1]={type="nuke", damageATK=30, target=0},	-- Heel Bite: Damage closest enemy for (0.3*attack) [VERIFIED]
		[2]={type="aura", plusDamageDealtATK=1, target=0, duration=2},	-- Heel Bite: Mod damage done of closest enemy by (0.01*attack) for 2 rounds [VERIFIED] #Bug/#Workaround: ignored incorrect Effect.Points
	},
	[347]={type="nuke", damageATK=100, target="cone"},	-- Darkness from Above: Damage closest cone of enemies for (1*attack) [VERIFIED]
	[348]={
		[1]={type="nuke", damageATK=120, target=1},	-- Tainted Bite: Damage furthest enemy for (1.2*attack) [VERIFIED]
		[2]={type="aura", plusDamageTakenATK=20, target=1, duration=3},	-- Tainted Bite: Mod damage taken of furthest enemy by (0.2*attack) for 3 rounds [VERIFIED]
	},
	[349]={type="nuke", damageATK=10, target="all-enemies"},	-- Anima Swell: Damage all enemies for (0.1*attack) [VERIFIED]
	[350]={type="nuke", damageATK=25, target="cleave"},	-- Attack Wave: Damage closest enemies for (0.25*attack) [UNVERFIED]
	[351]={type="nuke", damageATK=75, target=1, firstTurn=4},	-- Attack Pulse: Damage furthest enemy for (0.75*attack) [UNVERFIED]
	[352]={type="aura", modDamageTaken=30, target=4},	-- Active Shielding: Mod damage taken of self by 30% for 0 rounds [UNVERFIED]
	[353]={type="aura", modDamageDealt=20, target=1},	-- Disruptive Field: Mod damage done of furthest enemy by 20% for 0 rounds [UNVERFIED]
	[354]={type="nuke", damageATK=400, target="enemy-front", firstTurn=5},	-- Energy Blast: Damage frontmost row of enemies for (4*attack) [UNVERFIED]
	[355]={type="passive", modDamageDealt=-25, target=1},	-- Mitigation Aura: Mod damage done of furthest enemy by -25% indefinitely [UNVERFIED]
	[356]={type="nuke", damageATK=100, target=1},	-- Bone Ambush: Damage furthest enemy for (1*attack) [UNVERFIED] #Bug/#Workaround: ignored incorrect Effect.Target
	[357]={type="passive", modDamageDealt=-50, target=0},	-- Mitigation Aura: Mod damage done of closest enemy by -50% indefinitely [VERIFIED]
	[358]={type="nuke", damageATK=400, target="enemy-front", firstTurn=5},	-- Deconstructive Slam: Damage frontmost row of enemies for (4*attack) [VERIFIED]
	[359]={type="aura", damageATK=50, target=1, duration=4, period=3, noFirstTick=true},	-- Pain Projection: Damage (tick) furthest enemy for (0.5*attack) each subsequent 3rd round for 3 rounds [UNVERFIED]
	[360]={type="nuke", damageATK=50, target="enemy-front"},	-- Anima Draw: Damage frontmost row of enemies for (0.5*attack) [UNVERFIED]
	[361]={type="nuke", damageATK=75, target="enemy-front"},	-- Geostorm: Damage frontmost row of enemies for (0.75*attack) [UNVERFIED]
	[362]={type="nuke", damageATK=120, target=1},	-- Anima Stinger: Damage furthest enemy for (1.2*attack) [UNVERFIED]
	[363]={type="aura", modDamageDealt=10, target="friend-front-hard", duration=2},	-- Pack Instincts: Mod damage done of frontmost row of allies by 10% for 2 rounds [UNVERFIED]
	[364]={type="taunt", target="all-enemies", duration=2},	-- Intimidating Presence: Taunt all enemies for 2 rounds [UNVERFIED]
	[365]={type="aura", modDamageTaken=50, target=0, duration=1},	-- Mawsworn Strength: Mod damage taken of closest enemy by 50% for 1 rounds [UNVERFIED]
	[366]={type="nuke", damageATK=50, target="enemy-front"},	-- Domination Lash: Damage frontmost row of enemies for (0.5*attack) [UNVERFIED]
	[367]={type="nuke", damageATK=75, target="cone"},	-- Domination Thrust: Damage closest cone of enemies for (0.75*attack) [VERIFIED]
	[368]={type="nuke", damageATK=60, target=1},	-- Domination Bombardment: Damage furthest enemy for (0.6*attack) [VERIFIED]
	[369]={type="aura", damagePerc=100, target="all-enemies", duration=3, period=2, nore=true},	-- Power of Domination: Damage (tick) all enemies for 100% immediately and each subsequent 2nd round for 2 rounds [VERIFIED] #Bug/#Workaround: ignored incorrect Effect.Type or Effect.Flags
	[370]={type="aura", modDamageDealt=-50, target="all-enemies", duration=2},	-- Dominating Presence: Mod damage done of all enemies by -50% for 2 rounds [VERIFIED]
	[371]={type="aura", modDamageTaken=-25, target="all-other-allies", duration=2},	-- Acceleration Field: Mod damage taken of all-other allies by -25% for 2 rounds [VERIFIED]
	[372]={type="nuke", damageATK=80, target="enemy-front"},	-- Mace Smash: Damage frontmost row of enemies for (0.8*attack) [UNVERFIED]
	[373]={
		[1]={type="nuke", damageATK=100, target=1},	-- Repurpose Anima Flow: Damage furthest enemy for (1*attack) [UNVERFIED]
		[2]={type="heal", healATK=100, target=4},	-- Repurpose Anima Flow: Heal self for (1*attack) [UNVERFIED]
	},
	[374]={
		[1]={type="nuke", damageATK=100, target=1},	-- Anima Thirst: Damage furthest enemy for (1*attack) [VERIFIED]
		[2]={type="heal", healATK=40, target=4},	-- Anima Thirst: Heal self for (0.4*attack) [VERIFIED]
	},
	[375]={type="aura", modDamageDealt=-20, target="all-enemies", duration=2},	-- Tangling Roots: Mod damage done of all enemies by -20% for 2 rounds [VERIFIED]
}
local function checkForMultiKeys(e,nk)
	for k in pairs(e) do
		if type(nk) == "table" and #nk > 0 then
			local nks = nk
			for nki,nkv in ipairs(nks) do
				if nkv == k then
					nk = k
					break
				end
			end
		end
		if not nk or k ~= nk then
			if k == "damageATK1" or
			k == "selfhealATK" or
			k == "damageATK" or
			k == "damagePerc" or
			k == "healATK" or
			k == "healPerc" or
			k == "healPercent" or
			k == "shroudTurns" or
			k == "plusDamageDealtATK" or
			k == "modDamageDealt" or
			k == "plusDamageTakenATK" or
			k == "modDamageTaken" or
			k == "thornsATK" or
			k == "thornsPerc" or
			k == "modMaxHPATK" or
			k == "modMaxHP" then return k end
		end
	end
end
local function countMultiKeys(e,nk)
	local c = 0
	for k in pairs(e) do
		if type(nk) == "table" and #nk > 0 then
			local nks = nk
			for nki,nkv in ipairs(nks) do
				if nkv == k then
					nk = k
					break
				end
			end
		end
		if not nk or k ~= nk then
			if k == "damageATK1" or
			k == "selfhealATK" or
			k == "damageATK" or
			k == "damagePerc" or
			k == "healATK" or
			k == "healPerc" or
			k == "healPercent" or
			k == "shroudTurns" or
			k == "plusDamageDealtATK" or
			k == "modDamageDealt" or
			k == "plusDamageTakenATK" or
			k == "modDamageTaken" or
			k == "thornsATK" or
			k == "thornsPerc" or
			k == "modMaxHPATK" or
			k == "modMaxHP" then c=c+1 end
		end
	end
	return c-1
end
local function compareToVP(b,useOriginalVP)
	local a = vpData
	local bkc = {}
	for k, v in pairs(a) do
		if b[k] then
			bkc[k]=true
			local m = false
			if v.type == "nukem" then
				--print('['..k..']','is a merged multi-nuke effect:',#v.damageATK)
				m=true
				for di,dv in ipairs(v.damageATK) do
					v[di]={type="nuke", damageATK=dv, target=v.target,dne=v.dne}
				end
				v.type=nil
				v.target=nil
				v.damageATK=nil
			elseif checkForMultiKeys(v,checkForMultiKeys(v)) then
				local cba = true
				--print('['..k..']','is a merged multi-effect effect:',n)
				m=true
				if v.damageATK1 then
					v[1]={type="nuke",damageATK=v.damageATK1,target=v.target,dne=v.dne}
					v.damageATK1=nil
					cba=true
				end
				if v.damageATK or v.damagePerc then
					local ntd = checkForMultiKeys(v,{"damageATK","damagePerc","selfhealATK","damageATK1"})
					cba = cba and (not ntd or v.period) and (v.period or v.echo or v.duration)
					if not cba then
						v[#v+1]={type="nuke",damageATK=v.damageATK,damagePerc=v.damagePerc,target=v.target,dne=v.dne}
					else
						local d = v.duration
						if not useOriginalVP and v.echo then
							d = v.echo+1
						elseif d then
							d = ntd and d+1 or d
						end
						if useOriginalVP then
							v[#v+1]={type=(v.noFirstTick or not v.echo) and "aura" or "nuke",damageATK=v.damageATK,damagePerc=v.damagePerc,target=v.target,period=v.period,echo=v.echo,duration=not v.echo and d or nil,noFirstTick=v.noFirstTick,nore=v.nore,dne=v.dne}
						else
							v[#v+1]={type="aura",damageATK=v.damageATK,damagePerc=v.damagePerc,target=v.target,period=v.period or v.echo,duration=d,noFirstTick=v.noFirstTick,nore=v.nore,dne=v.dne}
						end
						cba = false
					end
					v.damageATK=nil
					v.damagePerc=nil
				end
				if v.selfhealATK then
					v[#v+1]={type="heal",healATK=v.selfhealATK,target=4,dne=v.dne}
					v.selfhealATK=nil
					n=true
				end
				if v.healATK or v.healPerc or v.healPercent then
					local ntd = checkForMultiKeys(v,{"damageATK","damagePerc","healATK","healPerc","healPercent","selfhealATK","damageATK1"})
					cba = cba and (not ntd or v.period) and (v.period or v.echo or v.duration)
					if not cba then
						v[#v+1]={type="heal",healATK=v.healATK,healPerc=v.healPerc or v.healPercent,target=v.target,dne=v.dne}
						if useOriginalVP and v.healPercent then
							v[#v].healPercent=v.healPercent
							v[#v].healPerc=nil
						end
						n=true
					else
						local d = v.duration
						if not useOriginalVP and v.echo then
							d = v.echo+1
						elseif d then
							d = ntd and d+1 or d
						end
						if useOriginalVP then
							v[#v+1]={type=(v.noFirstTick or not v.echo) and "aura" or "nuke",healATK=v.healATK,healPerc=v.healPerc,target=v.target,period=v.period,echo=v.echo,duration=not v.echo and d or nil,noFirstTick=v.noFirstTick,nore=v.nore,dne=v.dne}
						else
							v[#v+1]={type="aura",healATK=v.healATK,healPerc=v.healPerc,target=v.target,period=v.period or v.echo,duration=d,noFirstTick=v.noFirstTick,nore=v.nore,dne=v.dne}
						end
						cba = false
					end
					v.healATK=nil
					v.healPerc=nil
					v.healPercent=nil
				end
				if v.shroudTurns then
					if useOriginalVP then
						v[#v+1]={type="heal",target=v.target,shroudTurns=v.shroudTurns,dne=v.dne}
					else
						v[#v+1]={type="shroud",target=v.target,duration=v.shroudTurns,dne=v.dne}
						v.shroudTurns=nil
					end
					cba=false
				end
				if v.modDamageDealt or v.plusDamageDealtATK then
					v[#v+1]={type="aura",modDamageDealt=v.modDamageDealt,plusDamageDealtATK=v.plusDamageDealtATK,target=v.target,duration=v.duration,dne=v.dne}
					v.modDamageDealt=nil
					v.plusDamageDealtATK=nil
					cba=false
				end
				if v.modDamageTaken or v.plusDamageTakenATK then
					v[#v+1]={type="aura",modDamageTaken=v.modDamageTaken,plusDamageTakenATK=v.plusDamageTakenATK,target=v.target,duration=v.duration,dne=v.dne}
					v.modDamageTaken=nil
					v.plusDamageTakenATK=nil
					cba=false
				end
				if v.thornsATK or v.thornsPerc then
					v[#v+1]={type="aura",thornsATK=v.thornsATK,thornsPerc=v.thornsPerc,target=v.target,duration=v.duration,dne=v.dne}
					v.thornsATK=nil
					v.thornsPerc=nil
					cba=false
				end
				if v.modMaxHP or v.modMaxHPATK then
					v[#v+1]={type="aura",modMaxHP=v.modMaxHP,modMaxHPATK=v.modMaxHPATK,target=v.target,duration=v.duration,dne=v.dne}
					v.modMaxHP=nil
					v.modMaxHPATK=nil
					cba=false
				end
			end
			if not useOriginalVP then
				if v.shroudTurns then
					v.type="shroud"
					v.duration=v.shroudTurns
					v.shroudTurns=nil
				end
				if v.echo then
					v.type=v.type == "nuke" and "aura" or v.type
					v.period=v.echo
					v.duration=v.duration and v.duration > 1 and v.duration or (v.echo and v.echo+1 or nil)
					v.echo=nil
				end
			end
			v.type=not m and v.type or nil
			v.target=not m and v.target or nil
			v.period=not m and v.period or nil
			v.duration=not m and v.duration or nil
			v.noFirstTick=not m and v.noFirstTick or nil
			v.nore=not m and v.nore or nil
			v.dne=not m and v.dne or nil
			for kk,vv in pairs(v) do
				if type(b[k]) == 'table' and b[k][kk] then
					bkc[k..'.'..kk]=true
					if type(vv) ~= type(b[k][kk]) then
						print('['..k..']['..kk..']','different value type:',type(vv).."("..tostring(vv)..")",type(b[k][kk]).."("..tostring(b[k][kk])..")")
					elseif type(vv) == 'table' then
						local mm = false
						if vv.type == "nukem" then
							mm = true
							--print('['..k..']['..kk..']','is a merged multi-nuke effect:',#vv.damageATK)
							for di,dv in ipairs(vv.damageATK) do
								table.insert(vv,kk+di-1,{type="nuke", damageATK=dv, target=vv.target,dne=vv.dne})
							end
						elseif checkForMultiKeys(vv,checkForMultiKeys(vv)) then
							mm = true
							local n = countMultiKeys(vv)
							--print('['..k..']['..kk..']','is a merged multi-effect effect:',n)
							if vv.damageATK1 then
								table.insert(v,1,{type="nuke",damageATK=vv.damageATK1,target=vv.target,dne=vv.dne})
								vv.damageATK1=nil
								n=n-1
							end
							if n > 0 and (vv.modMaxHP or vv.modMaxHPATK) then
								table.insert(v,kk+1,{type="aura",modMaxHP=vv.modMaxHP,modMaxHPATK=vv.modMaxHPATK,target=vv.target,duration=vv.duration,dne=vv.dne})
								vv.modMaxHP=nil
								vv.modMaxHPATK=nil
								n=n-1
							end
							if n > 0 and (vv.thornsATK or vv.thornsPerc) then
								table.insert(v,kk+1,{type="aura",thornsATK=vv.thornsATK,thornsPerc=vv.thornsPerc,target=vv.target,duration=vv.duration,dne=vv.dne})
								vv.thornsATK=nil
								vv.thornsPerc=nil
								n=n-1
							end
							if n > 0 and (vv.modDamageTaken or vv.plusDamageTakenATK) then
								table.insert(v,kk+1,{type="aura",modDamageTaken=vv.modDamageTaken,plusDamageTakenATK=vv.plusDamageTakenATK,target=vv.target,duration=vv.duration,dne=vv.dne})
								vv.modDamageTaken=nil
								vv.plusDamageTakenATK=nil
								n=n-1
							end
							if n > 0 and (vv.modDamageDealt or vv.plusDamageDealtATK) then
								table.insert(v,kk+1,{type="aura",modDamageDealt=vv.modDamageDealt,plusDamageDealtATK=vv.plusDamageDealtATK,target=vv.target,duration=vv.duration,dne=vv.dne})
								vv.modDamageDealt=nil
								vv.plusDamageDealtATK=nil
								n=n-1
							end
							if n > 0 and vv.shroudTurns then
								if useOriginalVP then
									table.insert(v,kk+1,{type="heal",target=vv.target,shroudTurns=vv.shroudTurns,dne=vv.dne})
								else
									table.insert(v,kk+1,{type="shroud",target=vv.target,duration=vv.shroudTurns,dne=vv.dne})
									vv.shroudTurns=nil
								end
								n=n-1
							end
							if n > 0 and vv.selfhealATK then
								table.insert(v,kk+1,{type="heal",healATK=vv.selfhealATK,target=4,dne=vv.dne})
								vv.selfhealATK=nil
								n=n-1
							end
							if n > 0 and (vv.healATK or vv.healPerc or vv.healPecent) then
								if not vv.period and checkForMultiKeys(vv,{"healATK","healPerc","healPercent","damageATK","damagePerc","damageATK1","selfhealATK"}) then
									table.insert(v,kk+1,{type="heal",healATK=vv.healATK,healPerc=vv.healPerc or vv.healPercent,target=vv.target,dne=vv.dne})
									if useOriginalVP and vv.healPercent then
										v[kk+1].healPercent=v.healPercent
										v[kk+1].healPerc=nil
									end
								else
									table.insert(v,kk+1,{type=vv.type,healATK=vv.healATK,healPerc=vv.healPerc,target=vv.target,period=vv.period,duration=vv.duration+1,noFirstTick=vv.noFirstTick,nore=vv.nore,dne=vv.dne})
								end
								vv.healATK=nil
								vv.healPerc=nil
								vv.healPercent=nil
								n=n-1
							end
							if n > 0 and (vv.damageATK or vv.damagePerc) then
								if not vv.period and checkForMultiKeys(vv,{"healATK","healPerc","healPercent","damageATK","damagePerc","damageATK1","selfhealATK"}) then
									table.insert(v,kk+1,{type="nuke",damageATK=vv.damageATK,damagePerc=vv.damagePerc,target=vv.target,dne=vv.dne})
								else
									table.insert(v,kk+1,{type=vv.type,damageATK=vv.damageATK,damagePerc=vv.damagePerc,target=vv.target,period=vv.period,duration=vv.duration+1,noFirstTick=vv.noFirstTick,nore=vv.nore,dne=vv.dne})
								end
								vv.damageATK=nil
								vv.damagePerc=nil
								n=n-1
							end
						end
						if not useOriginalVP then
							if vv.shroudTurns then
								vv.type="shroud"
								vv.duration=vv.shroudTurns
								vv.shroudTurns=nil
							end
							if vv.echo then
								vv.type=vv.type == "nuke" and "aura" or vv.type
								vv.period=vv.echo
								vv.duration=vv.duration and vv.duration > 1 and vv.duration or (vv.echo and vv.echo+1 or nil)
								vv.echo=nil
							end
						end
						for kkk,vvv in pairs(vv) do
							if type(b[k][kk]) == 'table' and b[k][kk][kkk] then
								bkc[k..'.'..kk..'.'..kkk]=true
								if type(vvv) ~= type(b[k][kk][kkk]) then
									print('['..k..']['..kk..']['..kkk..']','different value type:',type(vvv),type(b[k][kk][kkk]))
								elseif vvv ~= b[k][kk][kkk] then
									print('['..k..']['..kk..']['..kkk..']','different value:',vvv,b[k][kk][kkk])
								end
							else
								print('['..k..']['..kk..']','property missing:',kkk,vvv)
							end
						end
					elseif vv ~= b[k][kk] then
						print('['..k..']['..kk..']','different value:',vv,b[k][kk])
					end
				else
					if type(b[k]) == 'table' and #b[k] > 0 and type(vv) ~= 'table' then
						local bkki, bkk = 1, false
						for bki,bk in ipairs(b[k]) do
							if type(bk) == 'table' and bk[kk] then
								bkki, bkk = bki, bk[kk]
								bkc[k..'.'..bkki..'.'..kk]=true
								if type(vv) ~= type(bkk) then
									print('['..k..']['..kk..']','missing property found on sub-effect ['..bkki..'] with a different value type:',type(vv)..'('..tostring(vv)..')',type(bkk)..'('..tostring(bkk)..')')
								elseif vv ~= bkk then
									print('['..k..']['..kk..']','missing property found on sub-effect ['..bkki..'] with a different value:',vv,bkk)
								else
									print('['..k..']['..kk..']','missing property found on sub-effect ['..bkki..'] with the same value:',vv,bkk)
								end
								break
							end
						end
						if not bkk then
							print('['..k..']','missing property not found on any sub-effects:',kk,vv)
						end
					else
						print('['..k..']','property missing:',kk,vv)
					end
				end
			end
		else
			print('Spell missing:',k,v)
		end
	end
	for k, v in pairs(b) do
		if not bkc[k] and type(v) == "table" then
			print('['..k..']','is a new spell')
		else
			for kk,vv in pairs(v) do
				if not bkc[k..'.'..kk] then
					if type(vv) == "table" then
						print('['..k..']['..kk..']','is a new effect')
					else
						print('['..k..']['..kk..']','is a new value:',vv)
					end
				else
					if type(vv) == "table" then
						for kkk,vvv in pairs(vv) do
							if not bkc[k..'.'..kk..'.'..kkk] then
								print('['..k..']['..kk..']['..kkk..']','is a new property with the value:',vvv)
							end
						end
					end
				end
			end
		end
	end
end

-- [ Data ]
local data = [[1	DNT JasonTest Envirospell	2	1	0	0	0	1	350	24	1	0	Damage all encounters for (1*attack) 	#N/A	Unused
2	DNT JasonTest Ability Spell	4	2	1	0	0	19	0.2	22	1	2	Mod damage done of all-other allies by (0.2*attack) for 2 rounds	#N/A	"Unused
Ignored: ineffective Effect.Period"
2	DNT JasonTest Ability Spell	4	2	1	0	1	4	1	1	0	0	Heal self for 100% 	#N/A	Unused
3	DNT Owen Test Double Effect	3	0	0	0	0	2	45.2	1	0	0	Heal self for 45.2 	#N/A	Unused
3	DNT Owen Test Double Effect	3	0	0	0	1	1	90.4	3	0	0	Damage closest enemy for 90.4 	#N/A	Unused
4	Double Strike	3	0	0	1	0	3	0.75	3	1	0	Damage closest enemy for (0.75*attack) 		
4	Double Strike	3	0	0	1	1	3	0.5	3	1	0	Damage closest enemy for (0.5*attack) 		
5	Wing Sweep	1	0	0	1	0	3	0.1	7	1	0	Damage all enemies for (0.1*attack) 		
6	Blood Explosion	2	0	0	100000	0	3	0.6	17	1	0	Damage backmost row of enemies for (0.6*attack) 		
7	Skeleton Smash	2	1	0	100000	0	3	0.1	3	1	0	Damage closest enemy for (0.1*attack) 	TRUE	
8	Hawk Punch	1	0	0	1000	0	1	10	3	1	0	Damage closest enemy for (1*attack) 	#N/A	"Unused
Ignored: incorrect Effect.Type, or ineffective Effect.Points"
9	Healing Howl	4	0	0	1000000	0	4	0.05	6	0	0	Heal all allies for 5% 	TRUE	
10	Starbranch Crush	3	3	0	10000	0	3	0.2	3	0	0	Damage closest enemy for 20% 	TRUE	
10	Starbranch Crush	3	3	0	10000	1	7	0.03	7	0	0	Damage (tick) all enemies for 3% each subsequent round for 3 rounds	TRUE	To-do: test dne=true behaviour
10	Starbranch Crush	3	3	0	10000	2	8	0.01	1	0	0	Heal (tick) self for 1% each subsequent round for 3 rounds	TRUE	
11	Auto Attack	0	0	0	1	0	1	1	3	1	0	Damage closest enemy for (1*attack) 	TRUE	
12	Bone Reconstruction	1	1	0	100000	0	4	0.2	6	1	0	Heal all allies for (0.2*attack) 	TRUE	
13	Gentle Caress	0	0	0	1000	0	2	10	2	0	0	Heal closest ally for 10 	#N/A	Unused
14	Spirit's Caress	3	0	0	100000	0	4	0.1	6	1	0	Heal all allies for (0.1*attack) 	#N/A	Unused
15	Auto Attack	0	0	0	1	0	1	0.5	5	1	0	Damage furthest enemy for (1*attack) 	TRUE	Ignored: incorrect Effect.Type
16	Soulshatter	1	0	0	100000	0	3	0.75	5	1	0	Damage furthest enemy for (0.75*attack) 		
17	Gravedirt Special	0	0	0	10000	0	3	0.1	7	1	0	Damage all enemies for (0.1*attack) 	TRUE	
17	Gravedirt Special	0	0	0	10000	1	2	100	1	1	0	Heal self for (1*attack) 	TRUE	Ignored: incorrect Effect.Type, or ineffective Effect.Points
17	Gravedirt Special	0	0	0	10000	2	0	0	7	1	0	Do nothing to all enemies for (0*attack) 	TRUE	Ignored: incorrect Effect
18	Wings of Fury	4	0	0	100000	0	3	0.2	15	1	0	Damage frontmost row of enemies for (0.2*attack) 		
18	Wings of Fury	4	0	0	100000	1	3	0.2	15	1	0	Damage frontmost row of enemies for (0.2*attack) 		
18	Wings of Fury	4	0	0	100000	2	3	0.2	15	1	0	Damage frontmost row of enemies for (0.2*attack) 		
19	Searing Bite	4	0	0	100	0	3	1.5	3	1	0	Damage closest enemy for (1.5*attack) 	TRUE	
20	Huck Stone	1	0	0	1	0	3	0.7	17	1	0	Damage backmost row of enemies for (0.7*attack) 		
21	Spirits of Rejuvenation	4	4	0	1	0	8	0.25	6	1	0	Heal (tick) all allies for (0.25*attack) each subsequent round for 4 rounds	TRUE	
22	Unrelenting Hunger	3	2	0	100000	0	3	0.9	9	1	0	Damage closest enemies for (0.9*attack) 		
22	Unrelenting Hunger	3	2	0	100000	1	7	0.1	9	1	0	Damage (tick) closest enemies for (0.1*attack) each subsequent round for 2 rounds		
23	DNT JasonTest Taunt Spell	0	2	0	0	0	10	11	1	0	0	Detaunt self for 2 rounds	#N/A	"Unused
Ignored: ineffective Effect.Points"
23	DNT JasonTest Taunt Spell	0	2	0	0	1	7	0.1	11	0	0	Damage (tick) closest cone of enemies for 10% each subsequent round for 2 rounds	#N/A	Unused
24	Shining Spear	2	0	0	10	0	3	1.8	5	1	0	Damage furthest enemy for (1.8*attack) 	TRUE	
24	Shining Spear	2	0	0	10	1	4	0.2	2	1	0	Heal closest ally for (0.2*attack) 	TRUE	
25	Whirling Fists	2	3	0	10	0	3	0.5	15	1	0	Damage frontmost row of enemies for (0.5*attack) 	TRUE	
25	Whirling Fists	2	3	0	10	1	12	0.2	1	1	0	Mod damage done of self by 20% for 3 rounds	TRUE	
26	Physiker's Potion	3	2	0	1000	0	4	1	2	1	0	Heal closest ally for (1*attack) 	TRUE	
26	Physiker's Potion	3	2	0	1000	1	18	0.2	2	1	0	Mod max health of closest ally by (0.2*attack) for 2 rounds	TRUE	
27	XX - Test - Physical	0	0	0	1	0	1	1	3	1	0	Damage closest enemy for (1*attack) 	#N/A	Unused
28	XX - Test - Melee - Holy	0	0	0	10	0	1	1	3	1	0	Damage closest enemy for (1*attack) 	#N/A	Unused
29	XX - Test - Melee - Fire	0	0	0	100	0	1	1	3	1	0	Damage closest enemy for (1*attack) 	#N/A	Unused
30	XX - Test - Melee - Nature	0	0	0	1000	0	1	1	3	1	0	Damage closest enemy for (1*attack) 	#N/A	Unused
31	XX - Test - Melee - Frost	0	0	0	10000	0	1	1	3	1	0	Damage closest enemy for (1*attack) 	#N/A	Unused
32	XX - Test - Melee - Shadow	0	0	0	100000	0	1	1	3	1	0	Damage closest enemy for (1*attack) 	#N/A	Unused
33	XX - Test - Melee - Arcane	0	0	0	1000000	0	1	1	3	1	0	Damage closest enemy for (1*attack) 	#N/A	Unused
34	XX - Test - Ranged - Physical	0	0	0	1	0	1	1	7	1	0	Damage all enemies for (1*attack) 	#N/A	Unused
35	XX - Test - Ranged - Holy	0	0	0	10	0	1	1	7	1	0	Damage all enemies for (1*attack) 	#N/A	Unused
36	XX - Test - Ranged - Fire	0	0	0	100	0	1	1	7	1	0	Damage all enemies for (1*attack) 	#N/A	Unused
37	XX - Test - Ranged - Nature	0	0	0	1000	0	1	1	7	1	0	Damage all enemies for (1*attack) 	#N/A	Unused
38	XX - Test - Ranged - Frost	0	0	0	10000	0	1	1	7	1	0	Damage all enemies for (1*attack) 	#N/A	Unused
39	XX - Test - Ranged - Shadow	0	0	0	100000	0	1	1	7	1	0	Damage all enemies for (1*attack) 	#N/A	Unused
40	XX - Test - Ranged - Arcane	0	0	0	1000000	0	1	1	7	1	0	Damage all enemies for (1*attack) 	#N/A	Unused
41	Bag Smash	3	0	0	1	0	7	0.25	9	1	0	Damage (tick) closest enemies for (0.25*attack) each subsequent round for 0 rounds	#N/A	Unused
42	JasonTest Passive	0	0	0	0	0	16	0.1	1	0	0	Damage attacker of self for 10% indefinitely	#N/A	Unused
43	Leech Anima	1	0	0	100000	0	3	0.25	5	1	0	Damage furthest enemy for (0.25*attack) 	TRUE	
43	Leech Anima	1	0	0	100000	1	4	0.2	1	1	0	Heal self for (0.2*attack) 	TRUE	
44	Double Stab	3	0	0	1	0	3	0.5	3	1	0	Damage closest enemy for (0.5*attack) 	TRUE	
44	Double Stab	3	0	0	1	1	3	0.25	3	1	0	Damage closest enemy for (0.25*attack) 	TRUE	
45	Siphon Soul	2	0	0	1000000	0	3	0.75	5	1	0	Damage furthest enemy for (0.75*attack) 	TRUE	
45	Siphon Soul	2	0	0	1000000	1	4	0.25	1	1	0	Heal self for (0.25*attack) 	TRUE	
46	Shield of Tomorrow	2	1	0	10	0	14	-0.1	1	0	0	Mod damage taken of self by -10% for 1 rounds	TRUE	
46	Shield of Tomorrow	2	1	0	10	1	14	-0.1	16	0	0	Mod damage taken of backmost row of allies by -10% for 1 rounds	TRUE	To-do: test target="*-hard" behaviour
47	Protective Aura	0	0	0	100000	0	14	-0.2	6	0	0	Mod damage taken of all allies by -20% indefinitely		
48	Shadow Walk	4	1	0	100000	0	10	0	1	1	0	Detaunt self for 1 rounds		
48	Shadow Walk	4	1	0	100000	1	4	0.2	1	1	0	Heal self for (0.2*attack) 		
49	Exsanguination	4	4	0	100000	0	14	0.33	17	0	0	Mod damage taken of backmost row of enemies by 33% for 4 rounds		
50	Halberd Strike	3	0	0	1	0	3	1.2	5	1	0	Damage furthest enemy for (1.2*attack) 	TRUE	
51	Bonestorm	5	0	0	100000	0	3	0.75	15	1	0	Damage frontmost row of enemies for (0.75*attack) 		
52	Plague Song	5	4	0	1000	0	3	0.3	17	1	0	Damage backmost row of enemies for (0.3*attack) 	#N/A	"Unused
Ignored: incorrect Effect.Type"
53	Bramble Trap	6	6	0	1000	0	7	0.1	7	1	2	Damage (tick) all enemies for (0.1*attack) each subsequent 2nd round for 6 rounds	#N/A	Unused
53	Bramble Trap	6	6	0	1000	1	12	-0.2	7	1	2	Mod damage done of all enemies by -20% for 6 rounds	#N/A	"Unused
Ignored: ineffective Effect.Period"
54	Slicing Shadows	3	0	0	100000	0	3	0.9	3	1	0	Damage closest enemy for (0.9*attack) 		
54	Slicing Shadows	3	0	0	100000	1	3	0.9	5	1	0	Damage furthest enemy for (0.9*attack) 		
55	Polite Greeting	4	0	0	1	0	3	1.5	15	1	0	Damage frontmost row of enemies for (1.5*attack) 		
56	Mirror of Torment	1	0	0	1000000	0	3	1.25	5	1	0	Damage furthest enemy for (1.25*attack) 		
57	Etiquette Lesson	5	3	0	100000	0	7	1	3	1	0	Damage (tick) closest enemy for (1*attack) each subsequent round for 3 rounds		
58	Headcrack	2	0	0	1	0	3	0.7	9	1	0	Damage closest enemies for (0.7*attack) 	TRUE	
59	Mirrors of Regret	3	0	0	1000000	0	3	0.5	17	1	0	Damage backmost row of enemies for (0.5*attack) 		
60	Acid Spit	2	0	0	1000	0	3	0.4	5	1	0	Damage furthest enemy for (0.4*attack) 	TRUE	
61	Mandible Smash	4	0	0	1000	0	3	0.75	3	1	0	Damage closest enemy for (0.75*attack) 	TRUE	
62	Gore	3	0	0	1000	0	3	0.3	15	1	0	Damage frontmost row of enemies for (0.3*attack) 	TRUE	
63	Sonic Shriek	5	2	0	1000	0	3	0.6	7	1	0	Damage all enemies for (0.6*attack) 	TRUE	
63	Sonic Shriek	5	2	0	1000	1	12	-0.2	7	0	0	Mod damage done of all enemies by -20% for 2 rounds	TRUE	
64	Massive Rumble	2	0	0	1000	0	3	1.5	7	1	0	Damage all enemies for (1.5*attack) 	TRUE	
65	Nagging Doubt	2	0	0	100000	0	3	0.65	3	1	0	Damage closest enemy for (0.65*attack) 	#N/A	Unused
66	Goliath Slam	1	0	0	100000	0	3	1.5	13	1	0	Damage closest column of enemies for (1.5*attack) 	TRUE	Ignored: ineffective Effect.Target
67	Vault Strike	3	0	0	100000	0	3	1.2	5	1	0	Damage furthest enemy for (1.2*attack) 	#N/A	Unused
68	Glowhoof Trample	3	1	1	10	0	3	0.2	15	1	0	Damage frontmost row of enemies for (0.2*attack) 	#N/A	Unused
68	Glowhoof Trample	3	1	1	10	1	12	-0.8	15	0	0	Mod damage done of frontmost row of enemies by -80% for 1 rounds	#N/A	"Unused
Ignored: incorrect Effect.Flags"
69	DNT JasonTest Ability Spell2	3	2	0	0	0	1	50	1	1	2	Damage self for (1*attack) 	#N/A	"Unused
Ignored: incorrect Effect.Type, and ineffective Effect.Period"
69	DNT JasonTest Ability Spell2	3	2	0	0	1	3	0.2	1	1	2	Damage self for (0.2*attack) 	#N/A	Unused
69	DNT JasonTest Ability Spell2	3	2	0	0	2	1	50	1	0	0	Damage self for 50 	#N/A	Unused
69	DNT JasonTest Ability Spell2	3	2	0	0	3	3	0.2	0	0	0	Damage nothing for 20% 	#N/A	"Unused
Ignored: ineffective Effect.Target"
70	DNT JasonTest Spell Tooltip	0	0	0	0	0	0	0	0	0	0	Do nothing to nothing for 0 	#N/A	Unused
71	Revitalizing Vines	2	0	0	1000	0	2	0.3	2	1	0	Heal closest ally for (1*attack) 	TRUE	Ignored: incorrect Effect.Type
72	Resonating Strike	4	0	0	10	0	3	2	3	1	0	Damage closest enemy for (2*attack) 	TRUE	
72	Resonating Strike	4	0	0	10	1	3	0.4	17	1	0	Damage backmost row of enemies for (0.4*attack) 	TRUE	
73	Purification Ray	2	0	0	10	0	3	1	13	1	0	Damage closest column of enemies for (1*attack) 	TRUE	
74	Reconfiguration: Defense	5	3	0	10	0	14	-0.4	1	0	0	Mod damage taken of self by -40% for 3 rounds	TRUE	
74	Reconfiguration: Defense	5	3	0	10	1	12	-0.4	1	0	0	Mod damage done of self by -40% for 3 rounds	TRUE	
75	Larion Leap	2	0	0	1	0	3	1.5	5	1	0	Damage furthest enemy for (1.5*attack) 	TRUE	
76	Phalynx Flash	3	0	0	10	0	3	2.25	5	1	0	Damage furthest enemy for (2.25*attack) 		
77	Potions of Penultimate Power	5	3	0	10	0	19	0.2	6	1	0	Mod damage done of all allies by (0.2*attack) for 3 rounds	TRUE	
78	Cleave	1	0	0	10	0	3	0.3	15	1	0	Damage frontmost row of enemies for (0.3*attack) 	TRUE	
79	Holy Nova	2	0	0	10	0	3	0.2	7	1	0	Damage all enemies for (0.2*attack) 	TRUE	
79	Holy Nova	2	0	0	10	1	4	0.2	6	1	0	Heal all allies for (0.2*attack) 	TRUE	
80	Dawnshock	3	2	0	100	0	3	1.2	5	1	0	Damage furthest enemy for (1.2*attack) 	TRUE	
80	Dawnshock	3	2	0	100	1	7	0.4	5	1	0	Damage (tick) furthest enemy for (0.4*attack) each subsequent round for 2 rounds	TRUE	
81	Reconfiguration: Reflect	5	3	0	10	0	15	3	1	1	0	Damage attacker of self for (1*attack) for 3 rounds	TRUE	Ignored: incorrect Effect.Type
82	Mace to Hand	0	0	0	1	0	16	0.25	1	1	0	Damage attacker of self for (0.25*attack) indefinitely	TRUE	
83	Lead the Charge	3	0	0	1	0	3	1.2	9	1	0	Damage closest enemies for (1.2*attack) 	TRUE	
84	Sparkling Driftglobe Core	4	2	1	1000000	0	12	-1	7	0	0	Mod damage done of all enemies by -100% for 2 rounds	TRUE	
85	Resilient Plumage	3	2	1	10	0	14	-50	2	0	0	Mod damage taken of closest ally by -5000% for 2 rounds	TRUE	Ignored: incorrect Effect.Points
86	[PH]Placeholder Punch	2	0	0	1	0	3	0.5	3	1	0	Damage closest enemy for (0.5*attack) 	#N/A	Unused
87	Doubt Defied	2	0	0	10	0	3	0.6	17	1	0	Damage backmost row of enemies for (0.6*attack) 	TRUE	
88	Combat Meditation	3	3	0	10	0	12	0.3	1	0	0	Mod damage done of self by 30% for 3 rounds	TRUE	
88	Combat Meditation	3	3	0	10	1	3	0.4	7	1	0	Damage all enemies for (0.4*attack) 	TRUE	
89	Spiked Burr Trap	4	2	0	1000	0	7	0.4	5	11	1	Damage (tick) furthest enemy for (0.4*attack) immediately and each subsequent round for 2 rounds	TRUE	
90	Invigorating Herbs	0	0	0	1000	0	12	0.2	8	0	0	Mod damage done of closest allies by 20% indefinitely	TRUE	
91	Dazzledust	4	3	0	1000	0	19	-0.6	5	1	0	Mod damage done of furthest enemy by (-0.6*attack) for 3 rounds	TRUE	
92	Trickster's Torment	2	2	0	100000	0	7	0.5	17	11	1	Damage (tick) backmost row of enemies for (0.5*attack) immediately and each subsequent round for 2 rounds	TRUE	
93	Leeching Seed	3	0	0	1000	0	3	0.2	3	1	0	Damage closest enemy for (0.2*attack) 	TRUE	
93	Leeching Seed	3	0	0	1000	1	4	0.8	1	1	0	Heal self for (0.8*attack) 	TRUE	
94	Icespore Spear	4	3	0	10000	0	7	0.3	15	1	1	Damage (tick) frontmost row of enemies for (0.3*attack) each subsequent round for 3 rounds	TRUE	
95	Starlight Strike	3	0	0	1000000	0	3	1.5	5	1	0	Damage furthest enemy for (1.5*attack) 	TRUE	
95	Starlight Strike	3	0	0	1000000	1	3	0.4	17	1	0	Damage backmost row of enemies for (0.4*attack) 	TRUE	
96	Insect Swarm	4	2	0	1000	0	3	0.6	5	1	0	Damage furthest enemy for (0.6*attack) 	TRUE	
96	Insect Swarm	4	2	0	1000	1	12	-0.3	5	0	0	Mod damage done of furthest enemy by -30% for 2 rounds	TRUE	
97	Flashing Arrows	2	1	0	1	0	3	0.9	11	1	0	Damage closest cone of enemies for (0.9*attack) 	TRUE	
98	Anima Bolt	1	0	0	1000000	0	3	1.2	5	1	0	Damage furthest enemy for (1.2*attack) 	TRUE	
99	Onslaught	3	1	0	1001	0	3	1.4	15	1	0	Damage frontmost row of enemies for (1.4*attack) 	TRUE	
100	Heart of the Forest	1	0	0	0	0	4	0.6	1	1	0	Heal self for (0.6*attack) 	TRUE	
101	Strangleheart Seed	4	3	0	10000	0	3	0.6	3	1	0	Damage closest enemy for (0.6*attack) 	TRUE	
101	Strangleheart Seed	4	3	0	10000	1	14	0.2	3	0	0	Mod damage taken of closest enemy by 20% for 3 rounds	TRUE	
102	Forest's Touch	2	0	0	1000	0	3	0.3	13	1	0	Damage closest column of enemies for (0.3*attack) 	TRUE	
103	Social Butterfly	4	2	0	1000	0	12	1	22	0	0	Mod damage done of all-other allies by 100% for 2 rounds	TRUE	
104	Podtender	1	1	0	1000	0	2	0.9	2	1	0	Heal closest ally for (1*attack) 	TRUE	Ignored: incorrect Effect.Type
104	Podtender	1	1	0	1000	1	12	-0.1	2	0	0	Mod damage done of closest ally by -10% for 1 rounds	TRUE	
105	Hold the Line	0	0	0	1	0	14	-0.1	6	0	0	Mod damage taken of all allies by -10% indefinitely	TRUE	
106	Face Your Foes	2	0	0	1	0	3	0.4	9	1	0	Damage closest enemies for (0.4*attack) 	TRUE	
107	Volatile Solvent	5	3	0	100000	0	7	1.5	3	11	0	Damage (tick) closest enemy for (1.5*attack) immediately and each subsequent round for 3 rounds	TRUE	
107	Volatile Solvent	5	3	0	100000	1	20	0.5	3	11	0	Mod damage taken of closest enemy by (0.5*attack) for 3 rounds	TRUE	Ignored: ineffective Effect.flags EXTRA_INITIAL_PERIOD
108	Ooz's Frictionless Coating	4	2	0	100000	0	4	0.4	2	1	0	Heal closest ally for (0.4*attack) 	TRUE	
108	Ooz's Frictionless Coating	4	2	0	100000	1	18	0.1	2	10	0	Mod max health of closest ally by 10% for 2 rounds	TRUE	Ignored: ineffective Effect.flags EXTRA_INITIAL_PERIOD
109	Serrated Shoulder Blades	0	0	0	1	0	16	0.6	1	1	0	Damage attacker of self for (0.6*attack) indefinitely		
110	Ravenous Brooch	1	0	0	100000	0	4	0.4	1	1	0	Heal self for (0.4*attack) 		
111	Sulfuric Emission	3	0	0	1000	0	3	1	15	1	0	Damage frontmost row of enemies for (1*attack) 		
112	Gnashing Chompers	5	3	0	100000	0	19	0.3	8	11	0	Mod damage done of closest allies by (0.3*attack) for 3 rounds		Ignored: ineffective Effect.flags EXTRA_INITIAL_PERIOD
113	Secutor's Judgment	4	0	0	110000	0	3	1.2	11	1	0	Damage closest cone of enemies for (1.2*attack) 		
114	Reconstruction	1	0	0	100000	0	2	0.6	1	1	0	Heal self for (1*attack) 		Ignored: incorrect Effect.Type
115	Dynamic Fist	2	0	0	100000	0	3	0.7	9	1	0	Damage closest enemies for (0.7*attack) 		
116	Dreaming Charge	3	0	0	1000	0	3	1.2	3	1	0	Damage closest enemy for (1.2*attack) 	TRUE	
117	Swift Slash	2	0	0	1000	0	3	0.4	15	1	0	Damage frontmost row of enemies for (0.4*attack) 	TRUE	
118	Mischievous Blast	4	0	1	1000	0	3	2	5	1	0	Damage furthest enemy for (2*attack) 	TRUE	
119	Corrosive Thrust	2	0	0	1000	0	3	1	11	1	0	Damage closest cone of enemies for (1*attack) 	TRUE	
120	Goading Motivation	2	2	0	1000	0	12	0.5	20	1	0	Mod damage done of random follower by 50% for 2 rounds	TRUE	
121	Mesmeric Dust	3	1	0	1000000	0	12	-0.5	7	1	0	Mod damage done of all enemies by -50% for 1 rounds	TRUE	
122	Humorous Flame	2	0	0	100	0	7	0.3	21	1	3	Damage (tick) random encounter for (0.3*attack) each subsequent 3rd round for 0 rounds	TRUE	Ignored: ineffective Spell.Duration and Effect.Period
123	Healing Winds	4	0	0	1000	0	4	0.3	14	1	0	Heal frontmost row of allies for (0.3*attack) 	TRUE	
124	Kick	3	0	0	1000	0	3	0.6	9	1	0	Damage closest enemies for (0.6*attack) 	TRUE	
125	Deranged Gouge	3	1	0	1000	0	3	0.6	20	1	0	Damage random follower for (0.6*attack) 	TRUE	
125	Deranged Gouge	3	1	0	1000	1	12	-0.5	20	0	1	Mod damage done of random follower by -50% for 1 rounds	TRUE	Ignored: ineffective Effect.Target and Effect.Period
126	Possessive Healing	3	1	0	1000	0	4	0.2	14	1	0	Heal frontmost row of allies for (0.2*attack) 	TRUE	
127	Nibble	4	1	0	1000	0	3	0.6	15	1	0	Damage frontmost row of enemies for (0.6*attack) 	TRUE	
128	Regurgitate	5	1	0	1000	0	3	0.75	17	1	0	Damage backmost row of enemies for (0.75*attack) 	TRUE	
129	Queen's Command	5	1	0	1000	0	4	0.3	6	1	0	Heal all allies for (0.3*attack) 	#N/A	Unused
129	Queen's Command	5	1	0	1000	1	12	0.5	6	0	1	Mod damage done of all allies by 50% for 1 rounds	#N/A	"Unused
Ignored: ineffective Effect.Period"
130	Carapace Thorns	4	3	0	1000	0	16	1	1	1	0	Damage attacker of self for (1*attack) for 3 rounds	TRUE	
131	Arcane Antlers	3	0	0	1000000	0	3	1.5	17	1	0	Damage backmost row of enemies for (1.5*attack) 	TRUE	
132	Arbor Eruption	4	1	0	1000	0	3	0.5	15	1	0	Damage frontmost row of enemies for (0.5*attack) 	TRUE	
132	Arbor Eruption	4	1	0	1000	1	12	-0.25	15	0	1	Mod damage done of frontmost row of enemies by -25% for 1 rounds	TRUE	Ignored: ineffective Effect.Period
133	Hidden Power	4	0	0	1000000	0	3	1	17	1	0	Damage backmost row of enemies for (1*attack) 	TRUE	
133	Hidden Power	4	0	0	1000000	1	4	0.75	1	1	0	Heal self for (0.75*attack) 	TRUE	
134	Curse of the Dark Forest	4	2	0	100000	0	14	0.25	7	1	0	Mod damage taken of all enemies by 25% for 2 rounds	TRUE	
135	Fires of Domination	3	0	0	100	0	3	3	17	1	0	Damage backmost row of enemies for (3*attack) 	TRUE	
136	Searing Jaws	4	3	0	100	0	7	1.5	3	1	3	Damage (tick) closest enemy for (1.5*attack) each subsequent 3rd round for 3 rounds		
137	Hearty Shout	4	2	0	1000	0	12	0.25	1	0	0	Mod damage done of self by 25% for 2 rounds		
138	Tail lash	2	0	0	1000000	0	3	0.3	9	1	0	Damage closest enemies for (0.3*attack) 	TRUE	
139	Hunger Frenzy	6	0	1	1000000	0	3	4	17	1	0	Damage backmost row of enemies for (4*attack) 	TRUE	
140	Fan of Knives	4	2	0	100000	0	3	0.6	17	1	0	Damage backmost row of enemies for (0.6*attack) 		
140	Fan of Knives	4	2	0	100000	1	12	-0.1	17	0	0	Mod damage done of backmost row of enemies by -10% for 2 rounds		
141	Herd Immunity	4	2	0	1000000	0	14	-0.5	6	0	0	Mod damage taken of all allies by -50% for 2 rounds	TRUE	
142	Arcane Restoration	3	0	0	1000000	0	4	0.7	10	1	0	Heal closest cone of allies for (0.7*attack) 	#N/A	Unused
143	Arrogant Boast	4	2	0	100000	0	12	0.25	1	0	2	Mod damage done of self by 25% for 2 rounds	TRUE	Ignored: ineffective Effect.Period
144	Ardent Defense	4	2	1	100000	0	14	-0.75	22	0	0	Mod damage taken of all-other allies by -75% for 2 rounds	TRUE	
145	Shield Bash	4	0	0	100000	0	3	0.75	3	1	0	Damage closest enemy for (0.75*attack) 	TRUE	
146	Dark Javelin	4	0	0	100000	0	3	0.75	5	1	0	Damage furthest enemy for (0.75*attack) 	TRUE	
147	Close Ranks	5	2	0	100000	0	14	-0.5	22	0	0	Mod damage taken of all-other allies by -50% for 2 rounds	TRUE	
148	Divine Maintenance	4	1	0	100000	0	4	1.25	14	1	0	Heal frontmost row of allies for (1.25*attack) 	TRUE	
149	Phalynx Slash	3	0	0	100000	0	3	0.75	15	1	0	Damage frontmost row of enemies for (0.75*attack) 	TRUE	
150	Crashing Claws	3	0	0	100000	0	3	0.5	11	1	0	Damage closest cone of enemies for (0.5*attack) 	TRUE	
151	Dive Bomb	2	1	0	100000	0	3	0.2	3	1	0	Damage closest enemy for (0.2*attack) 	TRUE	
152	Anima Wave	5	1	1	1000	0	4	2	22	1	0	Heal all-other allies for (2*attack) 	TRUE	
152	Anima Wave	5	1	1	1000	1	12	0.5	22	0	1	Mod damage done of all-other allies by 50% for 1 rounds	TRUE	
153	Forbidden Research	4	0	0	100000	0	3	0.75	11	1	0	Damage closest cone of enemies for (0.75*attack) 	TRUE	
154	Stolen Wards	5	3	0	100000	0	16	1	1	1	0	Damage attacker of self for (1*attack) for 3 rounds	TRUE	
155	Concussive Roar	4	1	0	100000	0	12	-0.75	7	0	0	Mod damage done of all enemies by -75% for 1 rounds	TRUE	
156	Cursed Knowledge	5	2	0	100000	0	14	0.4	7	0	0	Mod damage taken of all enemies by 40% for 2 rounds	TRUE	
157	Frantic Flap	4	0	0	1	0	3	0.8	9	1	0	Damage closest enemies for (0.8*attack) 	TRUE	
158	Explosion of Dark Knowledge	3	0	1	100000	0	3	3	17	1	0	Damage backmost row of enemies for (3*attack) 	TRUE	
159	Proclamation of Doubt	4	2	0	100000	0	12	-0.25	7	0	2	Mod damage done of all enemies by -25% for 2 rounds	TRUE	
160	Seismic Slam	3	0	0	1000	0	3	2	7	1	0	Damage all enemies for (2*attack) 		
161	Dark Command	4	1	0	1000	0	4	1	6	1	0	Heal all allies for (1*attack) 		
161	Dark Command	4	1	0	1000	1	12	0.25	6	0	0	Mod damage done of all allies by 25% for 1 rounds		
162	Curse of Darkness	5	2	0	100000	0	12	-0.5	7	0	0	Mod damage done of all enemies by -50% for 2 rounds		
163	Wave of Conviction	6	0	1	100000	0	3	4	7	1	0	Damage all enemies for (4*attack) 		
164	Dark Flame	6	3	0	100000	0	7	2	11	11	3	Damage (tick) closest cone of enemies for (2*attack) immediately and each subsequent 3rd round for 3 rounds	TRUE	
165	Winged Assault	4	0	0	100000	0	3	3	3	1	0	Damage closest enemy for (3*attack) 	TRUE	
166	Leeching Bite	2	0	0	100000	0	3	1	21	1	0	Damage random encounter for (1*attack) 	TRUE	
166	Leeching Bite	2	0	0	100000	1	4	0.5	1	1	0	Heal self for (0.5*attack) 	TRUE	
167	Razor Shards	4	0	0	1000	0	3	1.5	5	1	0	Damage furthest enemy for (1.5*attack) 	TRUE	
168	Howl from Beyond	4	2	0	100000	0	12	-0.5	3	0	0	Mod damage done of closest enemy by -50% for 2 rounds	TRUE	
169	Consuming Strike	5	3	0	100000	0	3	0.65	3	1	0	Damage closest enemy for (0.65*attack) 	TRUE	
169	Consuming Strike	5	3	0	100000	1	7	0.5	3	11	3	Damage (tick) closest enemy for (0.5*attack) immediately and each subsequent 3rd round for 3 rounds	TRUE	To-do: test nore=true
170	Stone Bash	4	1	0	1000	0	3	0.6	15	1	0	Damage frontmost row of enemies for (0.6*attack) 	TRUE	
171	Pitched Boulder	3	1	0	1000	0	3	1	5	1	0	Damage furthest enemy for (1*attack) 	TRUE	
172	Viscous Slash	3	1	1	100000	0	3	0.2	15	1	0	Damage frontmost row of enemies for (0.2*attack) 	TRUE	
172	Viscous Slash	3	1	1	100000	1	12	-0.5	15	0	0	Mod damage done of frontmost row of enemies by -50% for 1 rounds	TRUE	
173	Icy Blast	4	2	0	10000	0	3	0.75	5	1	0	Damage furthest enemy for (0.75*attack) 	TRUE	
173	Icy Blast	4	2	0	10000	1	12	-0.25	5	0	0	Mod damage done of furthest enemy by -25% for 2 rounds	TRUE	
174	Polished Ice Barrier	4	3	0	10000	0	16	0.4	1	1	0	Damage attacker of self for (0.4*attack) for 3 rounds	TRUE	
175	Lash Out	3	0	0	100000	0	3	1.2	19	1	0	Damage random target for (1.2*attack) 	TRUE	
176	Arrogant Denial	3	1	0	100000	0	14	0.25	7	0	0	Mod damage taken of all enemies by 25% for 1 rounds	TRUE	
177	Shoulder Charge	3	0	0	1	0	3	0.5	3	1	0	Damage closest enemy for (0.5*attack) 	TRUE	
178	Draw Anima	4	0	0	100000	0	3	1	5	1	0	Damage furthest enemy for (1*attack) 	TRUE	
178	Draw Anima	4	0	0	100000	1	4	0.5	1	1	0	Heal self for (0.5*attack) 	TRUE	
179	Medical Advice	6	2	0	10	0	4	1	6	1	0	Heal all allies for (1*attack) 	TRUE	
179	Medical Advice	6	2	0	10	1	12	0.5	6	0	0	Mod damage done of all allies by 50% for 2 rounds	TRUE	
180	Mental Assault	3	0	0	100000	0	3	0.75	20	1	0	Damage random follower for (0.75*attack) 	TRUE	
181	Anima Blast	6	0	1	100000	0	3	1.5	17	1	0	Damage backmost row of enemies for (1.5*attack) 	TRUE	
182	Deceptive Practice	5	2	0	100000	0	12	-0.5	7	0	0	Mod damage done of all enemies by -50% for 2 rounds	TRUE	
183	Shadow Swipe	3	0	0	100000	0	3	0.5	15	1	0	Damage frontmost row of enemies for (0.5*attack) 	TRUE	
184	Anima Lash	4	0	0	100000	0	3	0.75	11	1	0	Damage closest cone of enemies for (0.75*attack) 	TRUE	
185	Temper Tantrum	4	0	0	100000	0	3	1	7	1	0	Damage all enemies for (1*attack) 		
186	Feral Rage	5	0	1	100000	0	3	2	15	1	0	Damage frontmost row of enemies for (2*attack) 	TRUE	
187	Toxic Miasma	5	2	0	100000	0	7	0.5	7	11	2	Damage (tick) all enemies for (0.5*attack) immediately and each subsequent 2nd round for 2 rounds		
188	Angry Smash	3	1	0	1	0	3	0.5	3	1	0	Damage closest enemy for (0.5*attack) 		
188	Angry Smash	3	1	0	1	1	12	-0.5	3	0	0	Mod damage done of closest enemy by -50% for 1 rounds		
189	Angry Bash	3	0	0	1	0	3	2	3	1	0	Damage closest enemy for (2*attack) 		
190	Anima Wave	3	0	0	100000	0	3	1.5	15	1	0	Damage frontmost row of enemies for (1.5*attack) 		
191	Toxic Dispersal	1	0	0	1000	0	1	0.2	7	1	0	Damage all enemies for (1*attack) 		Ignored: incorrect Effect.Type
191	Toxic Dispersal	1	0	0	1000	1	2	0.1	6	1	0	Heal all allies for (1*attack) 		Ignored: incorrect Effect.Type
192	Shadow Bolt	2	0	0	100000	0	3	1.6	5	1	0	Damage furthest enemy for (1.6*attack) 		
193	Flesh Eruption	2	0	0	100000	0	3	3	15	1	0	Damage frontmost row of enemies for (3*attack) 		
193	Flesh Eruption	2	0	0	100000	1	3	0.5	1	1	0	Damage self for (0.5*attack) 		
194	Potentiated Power	3	2	0	100000	0	19	0.4	2	1	0	Mod damage done of closest ally by (0.4*attack) for 2 rounds		
194	Potentiated Power	3	2	0	100000	1	14	-0.2	2	1	0	Mod damage taken of closest ally by -20% for 2 rounds		
194	Potentiated Power	3	2	0	100000	2	3	0.2	1	1	0	Damage self for (0.2*attack) 		
195	Creeping Chill	4	2	0	10000	0	7	0.8	11	11	1	Damage (tick) closest cone of enemies for (0.8*attack) immediately and each subsequent round for 2 rounds		
196	Hail of Blades	5	0	0	1	0	3	1.2	3	1	0	Damage closest enemy for (1.2*attack) 		
196	Hail of Blades	5	0	0	1	1	3	0.9	3	1	0	Damage closest enemy for (0.9*attack) 		
196	Hail of Blades	5	0	0	1	2	3	0.6	3	1	0	Damage closest enemy for (0.6*attack) 		
196	Hail of Blades	5	0	0	1	3	3	0.3	3	1	0	Damage closest enemy for (0.3*attack) 		
197	Reassembly	2	0	0	100000	0	4	0.55	8	1	0	Heal closest allies for (0.55*attack) 		
198	Bone Shield	3	2	0	100000	0	20	-0.6	1	11	0	Mod damage taken of self by (-0.6*attack) for 2 rounds		
198	Bone Shield	3	2	0	100000	1	16	0.6	1	1	0	Damage attacker of self for (0.6*attack) for 2 rounds		
199	Lumbering swing	3	0	0	1	0	3	1	15	1	0	Damage frontmost row of enemies for (1*attack) 	TRUE	
200	Stunning Swipe	4	1	0	1000	0	3	1	15	1	0	Damage frontmost row of enemies for (1*attack) 	TRUE	
200	Stunning Swipe	4	1	0	1000	1	12	-0.5	15	0	1	Mod damage done of frontmost row of enemies by -50% for 1 rounds	TRUE	
201	Monstrous Rage	4	0	0	1000	0	3	2	17	1	0	Damage backmost row of enemies for (2*attack) 	TRUE	
202	Whirling Wall	4	2	0	1000	0	9	2	7	1	0	Taunt all enemies for 2 rounds	TRUE	
203	Bitting Winds	4	0	0	1000	0	3	1	15	1	0	Damage frontmost row of enemies for (1*attack) 	TRUE	
204	Death Blast	5	2	0	100000	0	3	1.5	3	1	0	Damage closest enemy for (1.5*attack) 	TRUE	
204	Death Blast	5	2	0	100000	1	12	-0.5	3	0	2	Mod damage done of closest enemy by -50% for 2 rounds	TRUE	
205	Bone Dust	3	0	0	1000	0	4	0.75	14	1	0	Heal frontmost row of allies for (0.75*attack) 	TRUE	
206	Abominable Kick	3	0	0	1	0	3	1.5	3	1	0	Damage closest enemy for (1.5*attack) 	TRUE	
207	Feral Lunge	2	0	0	1	0	3	0.3	13	1	0	Damage closest column of enemies for (0.3*attack) 	TRUE	Ignored: ineffective Effect.Target
208	Intimidating Roar	4	2	0	1000	0	9	2	21	1	0	Taunt random encounter for 2 rounds	TRUE	Ignored: ineffective Effect.Type and Effect.Target
209	Ritual Fervor	2	1	0	100000	0	12	0.5	21	0	0	Mod damage done of random encounter by 50% for 1 rounds	TRUE	
210	Waves of Death	3	0	0	100000	0	3	2	7	1	0	Damage all enemies for (2*attack) 	TRUE	
211	Acidic Ejection	4	0	0	1000	0	3	1.5	11	1	0	Damage closest cone of enemies for (1.5*attack) 	TRUE	
212	Panic Attack	4	0	0	1	0	3	2	19	1	0	Damage random target for (2*attack) 	TRUE	
213	Heal the Flock	3	0	0	1000	0	4	1	10	1	0	Heal closest cone of allies for (1*attack) 	TRUE	Ignored: ineffective Effect.Target
214	Necrotic Lash	2	0	0	100000	0	3	1	11	1	0	Damage closest cone of enemies for (1*attack) 	TRUE	
215	Slime Fist	5	0	0	1000	0	3	3	3	1	0	Damage closest enemy for (3*attack) 	TRUE	
216	Threatening Hiss	5	2	0	100000	0	10	3	1	1	0	Detaunt self for 2 rounds	TRUE	
217	Massacre	4	0	0	100000	0	3	2	17	1	0	Damage backmost row of enemies for (2*attack) 	TRUE	
218	Ritual of Bone	5	2	0	100000	0	14	-0.5	1	0	0	Mod damage taken of self by -50% for 2 rounds		
219	Necrotic Healing	6	2	0	100000	0	4	2	2	1	0	Heal closest ally for (2*attack) 		
219	Necrotic Healing	6	2	0	100000	1	14	-0.5	2	0	0	Mod damage taken of closest ally by -50% for 2 rounds		
220	Wild Slice	3	0	0	1	0	3	1	15	1	0	Damage frontmost row of enemies for (1*attack) 		
221	Burrow	5	2	0	1000	0	10	1.5	1	1	0	Detaunt self for 2 rounds		
222	Poisonous Bite	4	2	0	1000	0	3	0.3	3	1	0	Damage closest enemy for (0.3*attack) 		
222	Poisonous Bite	4	2	0	1000	1	7	0.3	3	11	2	Damage (tick) closest enemy for (0.3*attack) immediately and each subsequent 2nd round for 2 rounds		
223	Wave of Eternal Death	1	10	0	100000	0	7	0.1	23	1	1	Damage (tick) all followers for (0.1*attack) each subsequent round for 10 rounds	TRUE	
224	Maw Wrought Slash	3	0	0	1	0	3	0.5	15	1	0	Damage frontmost row of enemies for (0.5*attack) 	TRUE	
225	Stream of Anguish	2	0	0	100000	0	3	0.5	11	1	0	Damage closest cone of enemies for (0.5*attack) 	TRUE	
226	Thrust of the Maw	3	0	0	100000	0	3	0.5	11	1	0	Damage closest cone of enemies for (0.5*attack) 	TRUE	
227	Bombardment of Dread	1	0	0	100000	0	3	0.3	20	0	0	Damage random follower for 30% 	TRUE	
228	Destruction	10	0	1	100000	0	3	10	23	1	0	Damage all followers for (10*attack) 	TRUE	
229	Mawsworn Ritual	4	2	0	100000	0	14	-0.5	21	0	0	Mod damage taken of random encounter by -50% for 2 rounds	TRUE	
230	Faith in Domination	3	1	0	100000	0	4	0.5	24	1	0	Heal all encounters for (0.5*attack) 	TRUE	
231	Mawsworn Strength	4	2	0	100000	0	14	1	20	0	0	Mod damage taken of random follower by 100% for 2 rounds	TRUE	
232	Aura of Death	4	3	0	100000	0	12	-0.5	20	0	3	Mod damage done of random follower by -50% for 3 rounds	TRUE	
233	Teeth of the Maw	3	0	0	100000	0	3	1.5	3	1	0	Damage closest enemy for (1.5*attack) 	TRUE	
234	Power of Anguish	4	2	0	100000	0	12	0.5	21	0	0	Mod damage done of random encounter by 50% for 2 rounds	TRUE	
235	Vengence of the Mawsworn	3	0	0	100000	0	3	0.5	5	1	0	Damage furthest enemy for (0.5*attack) 	TRUE	
236	Empowered Minions	4	2	0	100000	0	14	-0.5	6	0	2	Mod damage taken of all allies by -50% for 2 rounds	TRUE	
237	Maw Swoop	4	0	0	100000	0	3	0.5	15	1	0	Damage frontmost row of enemies for (0.5*attack) 	TRUE	
238	Death Shield	4	2	0	1000	0	9	2	7	1	0	Taunt all enemies for 2 rounds	TRUE	Ignored: ineffective Effect.Points and Effect.Flags
239	Beam of Doom	5	0	0	100000	0	3	0.5	17	1	0	Damage backmost row of enemies for (0.5*attack) 	TRUE	
240	Spear of Dread	3	0	0	100000	0	3	0.25	13	1	0	Damage closest column of enemies for (0.25*attack) 	TRUE	Ignored: ineffective Effect.Target
241	Pain Spike	4	2	0	100000	0	3	0.75	5	1	0	Damage furthest enemy for (0.75*attack) 	TRUE	
241	Pain Spike	4	2	0	100000	1	12	-0.5	5	0	0	Mod damage done of furthest enemy by -50% for 2 rounds	TRUE	
242	Dark Healing	4	2	0	100000	0	4	0.5	2	1	0	Heal closest ally for (0.5*attack) 	TRUE	
242	Dark Healing	4	2	0	100000	1	14	0.75	2	0	0	Mod damage taken of closest ally by 75% for 2 rounds	TRUE	
243	Baleful Stare	5	2	0	100000	0	9	0	7	1	0	Taunt all enemies for 2 rounds	TRUE	
243	Baleful Stare	5	2	0	100000	1	14	-0.5	1	0	0	Mod damage taken of self by -50% for 2 rounds	TRUE	
244	Meatball Mad!	2	2	1	1	0	19	2	1	1	0	Mod damage done of self by (2*attack) for 2 rounds	TRUE	
244	Meatball Mad!	2	2	1	1	1	20	0.3	1	1	0	Mod damage taken of self by (0.3*attack) for 2 rounds	TRUE	
244	Meatball Mad!	2	2	1	1	2	3	0.3	3	1	0	Damage closest enemy for (0.3*attack) 	TRUE	
245	Crusader Strike	3	0	0	10	0	3	1.2	3	1	0	Damage closest enemy for (1.2*attack) 	TRUE	
246	Snarling Bite	2	0	0	1	0	3	1.5	3	1	0	Damage closest enemy for (1.5*attack) 	TRUE	
247	Skymane Strike	4	1	1	10	0	3	0.1	3	1	0	Damage closest enemy for (0.1*attack) 	TRUE	
247	Skymane Strike	4	1	1	10	1	4	0.2	1	1	0	Heal self for (0.2*attack) 	TRUE	
248	Infectious Soulbite	5	4	0	100000	0	3	0.3	3	1	0	Damage closest enemy for (0.3*attack) 	TRUE	
248	Infectious Soulbite	5	4	0	100000	1	7	0.15	3	1	1	Damage (tick) closest enemy for (0.15*attack) each subsequent round for 4 rounds	TRUE	
249	Shield Bash	3	1	0	1	0	3	0.6	3	1	0	Damage closest enemy for (0.6*attack) 	TRUE	
249	Shield Bash	3	1	0	1	1	12	-0.5	3	0	0	Mod damage done of closest enemy by -50% for 1 rounds	TRUE	
250	Thorned Slingshot	4	0	1	1000	0	3	0.8	5	1	0	Damage furthest enemy for (0.8*attack) 	TRUE	
251	Doom of the Drust	5	2	0	100000	0	12	-0.2	7	0	0	Mod damage done of all enemies by -20% for 2 rounds	TRUE	
252	Viscous Sweep	4	2	0	100000	0	3	0.6	9	1	0	Damage closest enemies for (0.6*attack) 	TRUE	
252	Viscous Sweep	4	2	0	100000	1	14	0.25	9	0	0	Mod damage taken of closest enemies by 25% for 2 rounds	TRUE	
253	Drust Claws	3	0	0	100000	0	3	0.75	15	1	0	Damage frontmost row of enemies for (0.75*attack) 	TRUE	
254	Drust Thorns	3	3	1	1000	0	16	1	22	1	0	Damage attacker of all-other allies for (1*attack) for 3 rounds	TRUE	
255	Defense of the Drust	3	1	0	100000	0	14	-0.5	2	0	0	Mod damage taken of closest ally by -50% for 1 rounds	TRUE	
256	Drust Blast	2	0	0	100000	0	3	1	11	1	0	Damage closest cone of enemies for (1*attack) 	TRUE	
257	Dread Roar	4	2	0	100000	0	10	1	1	1	0	Detaunt self for 2 rounds	TRUE	
258	Dark Gouge	5	3	0	100000	0	3	1	3	1	0	Damage closest enemy for (1*attack) 	TRUE	
258	Dark Gouge	5	3	0	100000	1	7	0.5	3	11	3	Damage (tick) closest enemy for (0.5*attack) immediately and each subsequent 3rd round for 3 rounds	TRUE	To-do: test nore=true
259	Anima Flame	2	3	0	1000000	0	7	0.3	3	1	3	Damage (tick) closest enemy for (0.3*attack) each subsequent 3rd round for 3 rounds	TRUE	
260	Anima Burst	3	0	0	1000000	0	3	1.5	5	1	3	Damage furthest enemy for (1.5*attack) 	TRUE	
261	Surgical Advances	4	2	0	100000	0	12	0.5	2	0	0	Mod damage done of closest ally by 50% for 2 rounds	TRUE	
262	Putrid Stomp	3	0	0	1000	0	3	1	15	1	0	Damage frontmost row of enemies for (1*attack) 	TRUE	
263	Acidic Vomit	4	0	0	1000	0	3	1	11	1	0	Damage closest cone of enemies for (1*attack) 	TRUE	
264	Meat Hook	4	0	0	1	0	3	3	5	1	0	Damage furthest enemy for (3*attack) 	TRUE	
265	Toxic Claws	4	0	0	1000	0	3	1	13	1	0	Damage closest column of enemies for (1*attack) 	TRUE	Ignored: ineffective Effect.Target
266	Colossal Strike	3	0	0	1	0	3	10	3	1	0	Damage closest enemy for (10*attack) 	TRUE	
267	Acidic Volley	3	0	0	1000	0	3	1.5	5	1	0	Damage furthest enemy for (1.5*attack) 	TRUE	
268	Acidic Spray	4	3	0	1000	0	12	-0.3	15	0	0	Mod damage done of frontmost row of enemies by -30% for 3 rounds	TRUE	
269	Acidic Stomp	4	0	0	1000	0	3	1.2	15	1	0	Damage frontmost row of enemies for (1.2*attack) 	TRUE	
270	Spidersong Webbing	4	2	0	1	0	12	-0.5	3	0	0	Mod damage done of closest enemy by -50% for 2 rounds	TRUE	
271	Ambush	4	3	0	1000	0	7	1	5	1	0	Damage (tick) furthest enemy for (1*attack) each subsequent round for 3 rounds	TRUE	
272	Soulfrost Shard	3	0	0	1000	0	3	1.5	5	1	0	Damage furthest enemy for (1.5*attack) 	TRUE	
273	Ritual Curse	2	1	0	100000	0	12	-0.5	3	0	0	Mod damage done of closest enemy by -50% for 1 rounds	#N/A	Unused
274	Stomp Flesh	4	0	0	1000	0	3	1.2	15	1	0	Damage frontmost row of enemies for (1.2*attack) 	TRUE	
275	Necromantic Infusion	4	2	0	100000	0	12	0.75	2	0	0	Mod damage done of closest ally by 75% for 2 rounds	TRUE	
276	Rot Volley	3	3	0	100000	0	3	0.25	5	1	0	Damage furthest enemy for (0.25*attack) 	TRUE	
276	Rot Volley	3	3	0	100000	1	7	0.5	5	11	3	Damage (tick) furthest enemy for (0.5*attack) immediately and each subsequent 3rd round for 3 rounds	TRUE	"To-do: test nore=true
"
277	Seething Rage	4	2	0	1000	0	12	1	1	0	0	Mod damage done of self by 100% for 2 rounds	TRUE	
278	Memory Displacement	3	2	0	1000000	0	14	0.5	5	0	0	Mod damage taken of furthest enemy by 50% for 2 rounds	TRUE	
279	Painful Recollection	4	0	0	1000000	0	3	0.5	17	1	0	Damage backmost row of enemies for (0.5*attack) 	TRUE	
280	Quills	6	0	0	1	0	3	2.5	15	1	0	Damage frontmost row of enemies for (2.5*attack) 	TRUE	
281	Anima Spit	3	0	0	1000000	0	3	1.5	5	1	3	Damage furthest enemy for (1.5*attack) 	TRUE	
282	Charged Javelin	5	0	1	1	0	3	10	3	1	0	Damage closest enemy for (10*attack) 	TRUE	
283	Anima Claws	4	0	0	1000000	0	3	0.75	13	1	0	Damage closest column of enemies for (0.75*attack) 	TRUE	Ignored: ineffective Effect.Target
284	Empyreal Reflexes	4	1	0	1000000	0	14	-0.5	22	0	0	Mod damage taken of all-other allies by -50% for 1 rounds	TRUE	
285	Forsworn's Wrath	4	2	1	100000	0	14	0.5	7	0	0	Mod damage taken of all enemies by 50% for 2 rounds	TRUE	
286	CHARGE!	3	2	0	1	0	12	0.5	2	0	0	Mod damage done of closest ally by 50% for 2 rounds	TRUE	
287	Elusive Duelist	3	1	0	1	0	14	-0.5	1	0	0	Mod damage taken of self by -50% for 1 rounds	TRUE	
288	Stone Swipe	4	0	0	1	0	3	0.6	17	1	0	Damage backmost row of enemies for (0.6*attack) 	TRUE	
289	Toxic Bolt	2	3	0	100000	0	7	1	5	11	3	Damage (tick) furthest enemy for (1*attack) immediately and each subsequent 3rd round for 3 rounds	TRUE	
290	Ashen Bolt	3	0	0	1000000	0	3	1.5	5	1	3	Damage furthest enemy for (1.5*attack) 	TRUE	
291	Ashen Blast	3	0	0	1000000	0	3	1	15	1	3	Damage frontmost row of enemies for (1*attack) 	TRUE	
292	Master's Surprise	2	2	0	1	0	14	0.5	3	0	0	Mod damage taken of closest enemy by 50% for 2 rounds	TRUE	
292	Master's Surprise	2	2	0	1	1	3	0.75	3	1	0	Damage closest enemy for (0.75*attack) 	TRUE	
293	Stone Crush	3	0	0	1	0	3	0.6	15	1	0	Damage frontmost row of enemies for (0.6*attack) 	#N/A	Unused
294	Stone Bash	3	0	0	1	0	3	2	3	1	0	Damage closest enemy for (2*attack) 	TRUE	
295	Dreadful Exhaust	2	2	0	100000	0	14	0.5	3	0	2	Mod damage taken of closest enemy by 50% for 2 rounds	TRUE	
296	Death Bolt	3	0	1	100000	0	3	1	17	1	0	Damage backmost row of enemies for (1*attack) 	TRUE	
297	Anima Thirst	4	0	0	100000	0	3	1	5	1	0	Damage furthest enemy for (1*attack) 	TRUE	
297	Anima Thirst	4	0	0	100000	1	4	0.3	1	1	0	Heal self for (0.3*attack) 	TRUE	
298	Anima Leech	4	0	0	100000	0	3	1	21	1	0	Damage random encounter for (1*attack) 	TRUE	
298	Anima Leech	4	0	0	100000	1	4	0.3	1	1	0	Heal self for (0.3*attack) 	TRUE	
299	Plague Blast	2	0	0	100000	0	3	2	5	1	0	Damage furthest enemy for (2*attack) 		
300	Wave of Eternal Death	1	3	0	100000	0	7	0.05	23	1	1	Damage (tick) all followers for (0.05*attack) each subsequent round for 3 rounds	TRUE	To-do: test stacking ticks from the same spell behaviour
301	Bombardment of Dread	1	0	0	100000	0	3	0.1	20	0	0	Damage random follower for 10% 	TRUE	
302	Bramble Trap	1	1	0	1000	0	3	0.2	7	1	2	Damage all enemies for (0.2*attack) 	TRUE	
302	Bramble Trap	1	1	0	1000	1	12	-0.2	7	1	0	Mod damage done of all enemies by -20% for 1 rounds	TRUE	
303	Plague Song	0	0	0	1000	0	3	0.25	17	1	0	Damage backmost row of enemies for (0.25*attack) 		
305	Roots of Submission	1	0	0	1000	0	3	1.2	17	1	0	Damage backmost row of enemies for (1.2*attack) 	TRUE	
306	Arcane Empowerment	3	3	0	1000000	0	19	0.4	2	1	0	Mod damage done of closest ally by (0.4*attack) for 3 rounds	TRUE	
306	Arcane Empowerment	3	3	0	1000000	1	18	0.6	2	1	0	Mod max health of closest ally by (0.6*attack) for 3 rounds	TRUE	
307	Fist of Nature	3	0	0	1000	0	3	1.6	11	1	0	Damage closest cone of enemies for (1.6*attack) 	TRUE	
308	Spore of Doom	3	0	1	1000	0	3	3.5	5	1	0	Damage furthest enemy for (3.5*attack) 	TRUE	
309	Threads of Fate	4	1	0	1000	0	4	2	6	1	0	Heal all allies for (2*attack) 	TRUE	
309	Threads of Fate	4	1	0	1000	1	12	0.3	6	0	0	Mod damage done of all allies by 30% for 1 rounds	TRUE	
310	Axe of Determination	2	2	0	10	0	3	1.4	3	1	0	Damage closest enemy for (1.4*attack) 		
310	Axe of Determination	2	2	0	10	1	12	0.2	1	0	0	Mod damage done of self by 20% for 2 rounds		
311	Wings of Mending	2	2	0	10	0	4	1.2	2	1	0	Heal closest ally for (1.2*attack) 		
311	Wings of Mending	2	2	0	10	1	18	0.4	2	1	0	Mod max health of closest ally by (0.4*attack) for 2 rounds		
312	Panoptic Beam	3	0	0	10	0	3	1.8	11	1	0	Damage closest cone of enemies for (1.8*attack) 		
313	Spirit's Guidance	0	0	0	10	0	4	0.7	6	1	0	Heal all allies for (0.7*attack) 		
314	Purifying Light	3	2	0	10	0	4	1.3	2	1	0	Heal closest ally for (1.3*attack) 	TRUE	
314	Purifying Light	3	2	0	10	1	19	0.5	2	1	0	Mod damage done of closest ally by (0.5*attack) for 2 rounds	TRUE	
315	Resounding Message	3	2	0	100	0	3	1.5	5	1	0	Damage furthest enemy for (1.5*attack) 	TRUE	
315	Resounding Message	3	2	0	100	1	12	-0.3	5	1	0	Mod damage done of furthest enemy by -30% for 2 rounds	TRUE	
316	Self Replication	1	0	0	100000	0	3	1	3	1	0	Damage closest enemy for (1*attack) 		
316	Self Replication	1	0	0	100000	1	4	0.3	1	1	0	Heal self for (0.3*attack) 		
317	Shocking Fist	3	1	0	100000	0	3	1.5	15	1	0	Damage frontmost row of enemies for (1.5*attack) 		
317	Shocking Fist	3	1	0	100000	1	20	0.3	15	1	0	Mod damage taken of frontmost row of enemies by (0.3*attack) for 1 rounds		
318	Inspiring Howl	3	3	0	1	0	19	0.5	6	1	0	Mod damage done of all allies by (0.5*attack) for 3 rounds		
319	Shattering Blows	4	3	0	100000	0	3	0.8	15	1	0	Damage frontmost row of enemies for (0.8*attack) 		
319	Shattering Blows	4	3	0	100000	1	7	0.5	15	1	0	Damage (tick) frontmost row of enemies for (0.5*attack) each subsequent round for 3 rounds		
320	Hailstorm	0	0	0	10000	0	3	1	17	1	0	Damage backmost row of enemies for (1*attack) 		
321	Adjustment	1	0	0	10000	0	4	2	2	1	0	Heal closest ally for (2*attack) 	TRUE	
322	Balance In All Things	2	1	0	10000	0	3	0.8	3	1	0	Damage closest enemy for (0.8*attack) 		
322	Balance In All Things	2	1	0	10000	1	4	0.8	1	1	0	Heal self for (0.8*attack) 		
322	Balance In All Things	2	1	0	10000	2	18	0.8	1	1	0	Mod max health of self by (0.8*attack) for 1 rounds		
323	Anima Shatter	3	2	0	0	0	3	0.4	17	1	0	Damage backmost row of enemies for (0.4*attack) 		
323	Anima Shatter	3	2	0	0	1	12	-0.1	17	0	0	Mod damage done of backmost row of enemies by -10% for 2 rounds		
324	Protective Parasol	1	0	0	100000	0	4	1.2	8	1	0	Heal closest allies for (1.2*attack) 		
325	Vision of Beauty	3	2	0	100000	0	12	0.6	8	0	0	Mod damage done of closest allies by 60% for 2 rounds		
326	Shiftless Smash	4	0	0	10000	0	3	0.25	9	1	0	Damage closest enemies for (0.25*attack) 	TRUE	
327	Inspirational Teachings	5	3	0	100000	0	19	0.2	22	1	0	Mod damage done of all-other allies by (0.2*attack) for 3 rounds	TRUE	
328	Applied Lesson	2	0	0	100001	0	3	0.3	3	1	0	Damage closest enemy for (0.3*attack) 	TRUE	
329	Muscle Up	5	3	0	100	0	14	-0.5	1	0	0	Mod damage taken of self by -50% for 3 rounds	TRUE	
330	Oversight	5	2	0	100	0	19	0.2	6	1	0	Mod damage done of all allies by (0.2*attack) for 2 rounds	TRUE	
331	Supporting Fire	3	3	0	100	0	19	0.2	22	1	0	Mod damage done of all-other allies by (0.2*attack) for 3 rounds	TRUE	
332	Emptied Mug	2	0	0	100000	0	3	1.5	5	1	0	Damage furthest enemy for (1.5*attack) 	TRUE	
333	Overload	5	3	0	1000000	0	19	0.4	1	1	0	Mod damage done of self by (0.4*attack) for 3 rounds	TRUE	
334	Hefty Package	2	0	0	100000	0	3	0.9	3	1	0	Damage closest enemy for (0.9*attack) 	TRUE	
335	Errant Package	2	0	0	1000000	0	3	0.4	17	1	0	Damage backmost row of enemies for (0.4*attack) 	TRUE	
336	Evidence of Wrongdoing	3	0	0	100	0	4	0.8	2	1	0	Heal closest ally for (0.8*attack) 	TRUE	
337	Wavebender's Tide	4	3	0	10000	0	3	2	5	1	0	Damage furthest enemy for (2*attack) 	TRUE	
337	Wavebender's Tide	4	3	0	10000	1	7	0.4	5	1	0	Damage (tick) furthest enemy for (0.4*attack) each subsequent round for 3 rounds	TRUE	
338	Scallywag Slash	2	0	0	1	0	3	0.5	3	1	0	Damage closest enemy for (0.5*attack) 	TRUE	
339	Cannon Barrage	3	0	1	100	0	3	1.2	7	1	0	Damage all enemies for (1.2*attack) 	TRUE	
340	Tainted Bite	3	0	0	100	0	3	0.6	5	1	0	Damage furthest enemy for (0.6*attack) 	#N/A	Unused
341	Tainted Bite	5	3	0	100000	0	3	1.2	5	1	0	Damage furthest enemy for (1.2*attack) 	TRUE	
341	Tainted Bite	5	3	0	100000	1	20	0.2	5	1	0	Mod damage taken of furthest enemy by (0.2*attack) for 3 rounds	TRUE	
342	Regurgitated Meal	1	1	0	1000	0	3	1	3	1	0	Damage closest enemy for (1*attack) 	TRUE	
342	Regurgitated Meal	1	1	0	1000	1	19	-0.7	3	1	0	Mod damage done of closest enemy by (-0.7*attack) for 1 rounds	TRUE	
343	Sharptooth Snarl	3	1	0	1000000	0	3	0.8	15	1	0	Damage frontmost row of enemies for (0.8*attack) 	TRUE	
343	Sharptooth Snarl	3	1	0	1000000	1	12	0.2	1	0	0	Mod damage done of self by 20% for 1 rounds	TRUE	
344	Razorwing Buffet	1	0	0	100	0	3	0.3	7	1	0	Damage all enemies for (0.3*attack) 	TRUE	
345	Protective Wings	4	3	0	1000000	0	20	-0.3	6	1	0	Mod damage taken of all allies by (-0.3*attack) for 3 rounds	TRUE	
346	Heel Bite	4	2	0	1000	0	3	0.3	3	1	0	Damage closest enemy for (0.3*attack) 	TRUE	
346	Heel Bite	4	2	0	1000	1	19	0.01	3	1	0	Mod damage done of closest enemy by (0.01*attack) for 2 rounds	TRUE	Ignored: incorrect Effect.Points
347	Darkness from Above	2	0	0	100000	0	3	1	11	1	0	Damage closest cone of enemies for (1*attack) 	TRUE	
348	Tainted Bite	5	3	0	100000	0	3	1.2	5	1	0	Damage furthest enemy for (1.2*attack) 	TRUE	
348	Tainted Bite	5	3	0	100000	1	20	0.2	5	1	0	Mod damage taken of furthest enemy by (0.2*attack) for 3 rounds	TRUE	
349	Anima Swell	4	0	0	1000000	0	3	0.1	7	1	0	Damage all enemies for (0.1*attack) 	TRUE	
350	Attack Wave	4	0	0	1000000	0	3	0.25	9	1	0	Damage closest enemies for (0.25*attack) 		
351	Attack Pulse	4	0	1	1000000	0	3	0.75	5	1	0	Damage furthest enemy for (0.75*attack) 		
352	Active Shielding	4	0	0	1000000	0	14	0.3	1	1	2	Mod damage taken of self by 30% for 0 rounds		
353	Disruptive Field	4	0	0	1000000	0	12	0.2	5	1	2	Mod damage done of furthest enemy by 20% for 0 rounds		
354	Energy Blast	5	0	1	1000000	0	3	4	15	1	0	Damage frontmost row of enemies for (4*attack) 		
355	Mitigation Aura	0	0	0	1000000	0	12	-0.25	5	0	0	Mod damage done of furthest enemy by -25% indefinitely		
356	Bone Ambush	2	0	0	1	0	1	2	5	1	3	Damage furthest enemy for (1*attack) 		Ignored: incorrect Effect.Target
357	Mitigation Aura	0	0	0	1000000	0	12	-0.5	3	0	0	Mod damage done of closest enemy by -50% indefinitely	TRUE	
358	Deconstructive Slam	5	0	1	1	0	3	4	15	1	0	Damage frontmost row of enemies for (4*attack) 	TRUE	
359	Pain Projection	5	3	0	100000	0	7	0.5	5	1	3	Damage (tick) furthest enemy for (0.5*attack) each subsequent 3rd round for 3 rounds		
360	Anima Draw	3	0	0	1000000	0	3	0.5	15	1	0	Damage frontmost row of enemies for (0.5*attack) 		
361	Geostorm	4	0	0	1	0	3	0.75	15	1	0	Damage frontmost row of enemies for (0.75*attack) 		
362	Anima Stinger	4	0	0	1000000	0	3	1.2	5	1	0	Damage furthest enemy for (1.2*attack) 		
363	Pack Instincts	5	2	0	1000	0	12	0.1	14	0	0	Mod damage done of frontmost row of allies by 10% for 2 rounds	TRUE	
364	Intimidating Presence	6	2	0	1	0	9	0	7	0	0	Taunt all enemies for 2 rounds	TRUE	
365	Mawsworn Strength	3	1	0	100000	0	14	0.5	3	0	0	Mod damage taken of closest enemy by 50% for 1 rounds	TRUE	
366	Domination Lash	4	0	0	100000	0	3	0.5	15	1	0	Damage frontmost row of enemies for (0.5*attack) 	TRUE	
367	Domination Thrust	4	0	0	100000	0	3	0.75	11	1	0	Damage closest cone of enemies for (0.75*attack) 	TRUE	
368	Domination Bombardment	3	0	0	100000	0	3	0.6	5	1	0	Damage furthest enemy for (0.6*attack) 	TRUE	
369	Power of Domination	4	2	0	1	0	7	1	7	10	2	Damage (tick) all enemies for 100% immediately and each subsequent 2nd round for 2 rounds	TRUE	Ignored: incorrect Effect.Type or Effect.Flags
370	Dominating Presence	5	2	0	1	0	12	-0.5	7	0	2	Mod damage done of all enemies by -50% for 2 rounds	TRUE	
371	Acceleration Field	5	2	0	1000	0	14	-0.25	22	0	0	Mod damage taken of all-other allies by -25% for 2 rounds	TRUE	
372	Mace Smash	4	0	0	1	0	3	0.8	15	1	0	Damage frontmost row of enemies for (0.8*attack) 		
373	Repurpose Anima Flow	5	0	0	1000000	0	3	1	5	1	0	Damage furthest enemy for (1*attack) 		
373	Repurpose Anima Flow	5	0	0	1000000	1	4	1	1	1	0	Heal self for (1*attack) 		
374	Anima Thirst	5	0	0	100000	0	3	1	5	1	0	Damage furthest enemy for (1*attack) 	TRUE	
374	Anima Thirst	5	0	0	100000	1	4	0.4	1	1	0	Heal self for (0.4*attack) 	TRUE	
375	Tangling Roots	4	2	0	1000	0	12	-0.2	7	1	0	Mod damage done of all enemies by -20% for 2 rounds	TRUE	
]]

-- [ Process ]
compareToVP(convertToVP(parseTSV(data,true),environmentStats,true))
--compareToVP(convertToVP(parseTSV(data),environmentStats,true,true),true)
