--Timer.lua-------------------------
--@jingzhou
--@2016-09-23
------------------------------------
--@func Timer.init()
--@desc 初始化Timer系统，app启动调用一次

--@func Timer.clean()
--@desc 停止所有Timer

--@func Timer.check(ref)
--@desc 获取TimerRef的剩余时间和次数
--@ret  timeLeft:float,至下次回调剩余时间
--@ret  loopLeft:int,剩余Loop次数

--@func Timer.call(time, func, loop=1, target=nil, useRealTime=false)
--@desc 延迟调用
--@ret  TimerRef:table, Timer句柄
--@arg  time:float,Timer间隔
--@arg　loop:int,循环次数，0表示一直循环
--@arg  target:GameObject,绑定Timer到go,go销毁时自动停止Timer
--@arg  useRealTime:true/false,使用RealTime，不受timeScale影响

--@func Timer.stop(ref)
--@desc 停止Timer
--@arg  ref:TimerRef,call返回的ref
------------------------------------

local Timer, super = defClassStatic("Timer")

Timer.init = function()
	if Timer._gameObject then
		return
	end
	local go = GameObject.Find("LuaTimerProxy")
	if not go then
		go = GameObject("LuaTimerProxy")
	end
	
    Timer._gameObject = go
    Timer._paused = false
    Timer.clean()
    
    GameObject.DontDestroyOnLoad(go)
	Event.add(go, Event.Update, function()
        Timer._exec(Timer._real, Timer._real.time + Time.unscaledDeltaTime, false)
        Timer._exec(Timer._game, Time.time, true)  
    end)
end

Timer.clean = function()
	Timer._game = {
        time = Time.time,
        lock = false,
        list = {},
        wait = {},
    }
    Timer._real = {
        time = Time.realtimeSinceStartup,
        lock = false,
        list = {},
        wait = {},
    }
end

--return timeleft, loopleft
Timer.check = function(ref)
    if ref == nil or ref[2] == nil then
		return
	end
    local inst = ref[5] and Timer._real or Timer._game
    return ref[6] - inst.time, ref[3]
end

--time:delay Time
--func:callback
--loop: 0 repeat forever   1...n repeat times
--target: gameobject  remove timer on destroy
--useRealTime: never be paused
Timer.call = function(time, func, loop, target, useRealTime)
	loop = loop or 1
	if loop == 0 then
		loop = -1
	end

	local ref = {time, func, loop, target, useRealTime, 0}
    if useRealTime then
        Timer._call(Timer._real, ref)
    else
        Timer._call(Timer._game, ref)
    end
    
    if target and InstanceOf(target, GameObject) then
        target:BindEvent(Event.OnDestroy, Timer.stop, ref)
    end
	return ref
end

Timer._call = function(inst, ref)
	if inst.lock then
		table.insert(inst.wait, ref)
	else
		local exec = inst.time + ref[1]
		ref[6] = exec

		local list = inst.list
		for i,v in ipairs(list) do
			if exec < v[6] then
				table.insert(list, i, ref)
				return
			end
		end

		table.insert(list, ref)
	end
end

Timer.stop = function(ref)
	if ref == nil or ref[2] == nil then
		return
	end
    ref[2] = nil
    
    local inst = ref[5] and Timer._real or Timer._game
	if not inst.lock then
		local list = inst.list
		for i,v in ipairs(list) do
			if v == ref then
				table.remove(list, i)
				break
			end
		end
	end
end

Timer._exec = function(inst, time, canBePaused)
    if canBePaused and Timer._paused then
        return
    end
    
    inst.time = time
    inst.lock = true
    
	local list = inst.list
    local wait = inst.wait
    
	local work = 0
	for i,v in ipairs(list) do
		if time >= v[6] then
            work = work + 1
            local fn = v[2]
			if fn then
				if v[3] == -1 then
					table.insert(wait, v)
				elseif v[3] > 1  then
					v[3] = v[3] - 1
					table.insert(wait, v)
                else
                    v[2] = nil
				end
                fn()
                if canBePaused and Timer._paused then
                    break
                end
			end
		else
			break
		end
	end

	if work > 0 then
		local n = #list
		for i = 1, n do
			list[i] = list[i+work]
		end
	end
	inst.lock = false

	for i,v in ipairs(wait) do
		Timer._call(inst, v)
        wait[i] = nil
	end
end

Timer.onAppPause = function()
    Timer._paused = true
end

Timer.onAppResume = function()
    Timer._paused = false
end


--[[
--unit test

Timer.init()

Timer.call(1, function() print("1-0") end, 0)
Timer.call(1, function() print("1-1") end)
Timer.call(2, function() print("2-1") end, 1)
Timer.call(2, function() print("2-3") end, 3)
local ref = Timer.call(3, function() print("3-0") end, 0)
Timer.call(3, function() print("3-2") end, 2)
Timer.stop(ref)

--]]


