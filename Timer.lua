--Timer.lua-------------------------
--@tianye112197
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

--@func Timer.call(time, func, loop=1, target=nil)
--@desc 延迟调用
--@ret  TimerRef:table, Timer句柄
--@arg  time:float,Timer间隔
--@arg　loop:int,循环次数，0表示一直循环
--@arg  target:GameObject,绑定Timer到go,go销毁时自动停止Timer

--@func Timer.stop(ref)
--@desc 停止Timer
--@arg  ref:TimerRef,call返回的ref
------------------------------------

local Timer, super = defClassStatic("Timer")

Timer._lock = false
Timer._time = 0
Timer._wait = {}
Timer._list = {}


Timer.init = function()
	if Timer.gameObject then
		return
	end
	local go = GameObject.Find("LuaTimerProxy")
	if not go then
		go = GameObject("LuaTimerProxy")
	end
	
    GameObject.DontDestroyOnLoad(go)
	Event.add(go, Event.Update, Timer.update)
    
    Timer.gameObject = go
    Timer._time = Time.time
end

Timer.clean = function()
	Timer._list = {}
    Timer._wait = {}
end

--return timeleft, loopleft
Timer.check = function(ref)
    if ref == nil or ref[2] == nil then
		return
	end
    return ref[5] - Timer._time, ref[3]
end

--time:delay Time
--func:callback
--loop: 0 repeat forever   1...n repeat times
--target: gameobject  remove timer on destroy
Timer.call = function(time, func, loop, target)
	loop = loop or 1
	if loop == 0 then
		loop = -1
	end

	local ref = {time, func, loop, target, 0}
	Timer._call(ref)

    if target and InstanceOf(target, GameObject) then
        target:BindEvent(Event.OnDestroy, Timer.stop, ref)
    end
	return ref
end

Timer._call = function(ref)
	if Timer._lock then
		table.insert(Timer._wait, ref)
	else
		local exec = Timer._time + ref[1]
		ref[5] = exec

		local list = Timer._list
		for i,v in ipairs(list) do
			if exec < v[5] then
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
	if not Timer._lock then
		local list = Timer._list
		for i,v in ipairs(list) do
			if v == ref then
				table.remove(list, i)
				break
			end
		end
	end
end


Timer.update = function()
	Timer._time = Time.time

	local time = Timer._time
	local list = Timer._list
	local work = 0

	Timer._lock = true
	for i,v in ipairs(list) do
		if time >= v[5] then
            work = work + 1
			if v[2] then
				v[2]()            

				if v[3] == -1 then
					table.insert(Timer._wait, v)
				elseif v[3] > 1  then
					v[3] = v[3] - 1
					table.insert(Timer._wait, v)
                else
                    v[2] = nil
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
	Timer._lock = false

	for i,v in ipairs(Timer._wait) do
		Timer._call(v)
	end
	Timer._wait = {}
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


