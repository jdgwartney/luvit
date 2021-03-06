--[[

Copyright 2012 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

-- Bootstrap require system
local native = require('uv_native')

local Emitter = require('core').Emitter

local Process = Emitter:extend()
process = Process:new()
process.execPath = native.execpath()
process.cwd = getcwd
process.argv = argv

require = require('module').require
local timer = require('timer')
local env = require('env')
local constants = require('constants')
local uv = require('uv')
local utils = require('utils')

_G.getcwd = nil
_G.argv = nil
_G.process = process

setmetatable(process, {
  __index = function (table, key)
    if key == "title" then
      return native.getProcessTitle()
    else
      return Emitter[key]
    end
  end,
  __newindex = function (table, key, value)
    if key == "title" then
      return native.setProcessTitle(value)
    else
      return rawset(table, key, value)
    end
  end,
  __pairs = function (table)
    local key = "title"
    return function (...)
      if key == "title" then
        key = next(table)
        return "title", table.title
      end
      if not key then return nil end
      local lastkey = key
      key = next(table, key)
      return lastkey, table[lastkey]
    end
  end
})

function signalStringToNumber(name)
  if name == 'SIGHUP' then
    return constants.SIGHUP
  elseif name == 'SIGINT' then
    return constants.SIGINT
  elseif name == 'SIGQUIT' then
    return constants.SIGQUIT
  elseif name == 'SIGILL' then
    return constants.SIGILL
  elseif name == 'SIGTRAP' then
    return constants.SIGTRAP
  elseif name == 'SIGABRT' then
    return constants.SIGABRT
  elseif name == 'SIGIOT' then
    return constants.SIGIOT
  elseif name == 'SIGBUS' then
    return constants.SIGBUS
  elseif name == 'SIGFPE' then
    return constants.SIGFPE
  elseif name == 'SIGKILL' then
    return constants.SIGKILL
  elseif name == 'SIGUSR1' then
    return constants.SIGUSR1
  elseif name == 'SIGSEGV' then
    return constants.SIGSEGV
  elseif name == 'SIGUSR2' then
    return constants.SIGUSR2
  elseif name == 'SIGPIPE' then
    return constants.SIGPIPE
  elseif name == 'SIGALRM' then
    return constants.SIGALRM
  elseif name == 'SIGTERM' then
    return constants.SIGTERM
  elseif name == 'SIGCHLD' then
    return constants.SIGCHLD
  elseif name == 'SIGSTKFLT' then
    return constants.SIGSTKFLT
  elseif name == 'SIGCONT' then
    return constants.SIGCONT
  elseif name == 'SIGSTOP' then
    return constants.SIGSTOP
  elseif name == 'SIGTSTP' then
    return constants.SIGSTSP
  elseif name == 'SIGTTIN' then
    return constants.SIGTTIN
  elseif name == 'SIGTTOU' then
    return constants.SIGTTOU
  elseif name == 'SIGURG' then
    return constants.SIGURG
  elseif name == 'SIGXCPU' then
    return constants.SIGXCPU
  elseif name == 'SIGXFSZ' then
    return constants.SIGXFSX
  elseif name == 'SIGVTALRM' then
    return constants.SIGVTALRM
  elseif name == 'SIGPROF' then
    return constants.SIGPROF
  elseif name == 'SIGWINCH' then
    return constants.SIGWINCH
  elseif name == 'SIGIO' then
    return constants.SIGIO
  elseif name == 'SIGPOLL' then
    return constants.SIGPOLL
  elseif name == 'SIGLOST' then
    return constants.SIGLOST
  elseif name == 'SIGPWR' then
    return constants.SIGPWR
  elseif name == 'SIGSYS' then
    return constants.SIGSYS
  elseif name == 'SIGUNUSED' then
    return constants.SIGUNUSED
  end
  return nil
end

--
process.signalWraps = {}
process.on = function(self, _type, listener)
  if _type:find('SIG') then
    local number = signalStringToNumber(_type)
    if number then
      local signal = process.signalWraps[_type]
      if not signal then
        signal = uv.Signal:new()
        process.signalWraps[_type] = signal
        signal:on('signal', function()
          self:emit(_type, number)
        end)
        signal:start(number)
      end
    end
  end
  Emitter.on(self, _type, listener)
end

process.removeListener = function(self, _type, callback)
  if _type:find('SIG') then
    local signal = process.signalWraps[_type]
    if signal then
      signal:stop()
      process.signalWraps[_type] = nil
    end
  end
  Emitter.removeListener(self, _type, callback)
end

-- Replace lua's stdio with luvit's
-- leave stderr using lua's blocking implementation
process.stdin = uv.createReadableStdioStream(0)
process.stdout = uv.createWriteableStdioStream(1)
process.stderr = uv.createWriteableStdioStream(2)

-- clear some globals
-- This will break lua code written for other lua runtimes
_G.io = nil
_G.os = nil
_G.loadfile = nil
_G.dofile = nil
_G.print = utils.print
_G.p = utils.prettyPrint

-- Move the version variables into a table
process.version = VERSION
process.versions = {
  luvit = VERSION,
  uv = native.VERSION_MAJOR .. "." .. native.VERSION_MINOR .. "-" .. UV_VERSION,
  luajit = LUAJIT_VERSION,
  yajl = YAJL_VERSION,
  zlib = ZLIB_VERSION,
  http_parser = HTTP_VERSION,
  openssl = OPENSSL_VERSION,
}
_G.VERSION = nil
_G.YAJL_VERSION = nil
_G.LUAJIT_VERSION = nil
_G.UV_VERSION = nil
_G.HTTP_VERSION = nil
_G.ZLIB_VERSION = nil
_G.OPENSSL_VERSION = nil

-- Add a way to exit programs cleanly
local exiting = false
function process.exit(exit_code)
  if exiting == false then
    exiting = true
    process:emit('exit', exit_code or 0)
  end
  exitProcess(exit_code or 0)
end

function process.nextTick(callback)
  timer.setTimeout(0, callback)
end

process.kill = native.kill

-- Add global access to the environment variables using a dynamic table
process.env = setmetatable({}, {
  __pairs = function (table)
    local keys = env.keys()
    local index = 0
    return function (...)
      index = index + 1
      local name = keys[index]
      if name then
        return name, table[name]
      end
    end
  end,
  __index = function (table, name)
    return env.get(name)
  end,
  __newindex = function (table, name, value)
    if value then
      env.set(name, value, 1)
    else
      env.unset(name)
    end
  end
})

--Retrieve PID
process.pid = native.getpid()

-- Copy date and time over from lua os module into luvit os module
local OLD_OS = require('os')
local OS_BINDING = require('os_binding')
package.loaded.os = OS_BINDING
package.preload.os_binding = nil
package.loaded.os_binding = nil
OS_BINDING.date = OLD_OS.date
OS_BINDING.time = OLD_OS.time
OS_BINDING.clock = OLD_OS.clock

-- This is called by all the event sources from C
-- The user can override it to hook into event sources
function eventSource(name, fn, ...)
  local args = {...}
  return assert(xpcall(function ()
    return fn(unpack(args))
  end, debug.traceback))
end

errorMeta = {__tostring=function(table) return table.message end}

local function usage()
  print("Usage: " .. process.argv[0] .. " [options] script.lua [arguments]"..[[


Options:
  -h, --help          Print this help screen.
  -v, --version       Print the version.
  -e code_chunk       Evaluate code chunk and print result.
  -i, --interactive   Enter interactive repl after executing script.
  -n, --no-color      Disable colors.
                      (Note, if no script is provided, a repl is run instead.)
  --cflags            Print CFLAGS.
  --libs              Print LDFLAGS.
]])
end

local realAssert = assert
function assert(good, error)
  return realAssert(good, tostring(error))
end

assert(xpcall(function ()

  -- Hook to allow bundled zips to take over main and arguments processing
  if zip then
    if zip.stat("main.lua") then
      assert(require('module').myloadfile("zip:main.lua"))()
      return
    end
    if zip.stat("main/init.lua") then
      assert(require('module').myloadfile("zip:main/init.lua"))()
      return
    end
  end

  local interactive = false
  local usecolors = true
  local showrepl = true
  local file
  local state = "BEGIN"
  local to_eval = {}
  local args = {[0]=process.argv[0]}

  for i, value in ipairs(process.argv) do
    if state == "BEGIN" then
      if value == "-h" or value == "--help" then
        usage()
        showrepl = false
      elseif value == "-v" or value == "--version" then
        print(process.version)
        showrepl = false
      elseif value == "-e" or value == "--eval" then
        state = "-e"
        showrepl = false
      elseif value == "-i" or value == "--interactive" then
        interactive = true
      elseif value == "-n" or value == "--no-color" then
        usecolors = false
      -- pkgconfig's --cflags
      elseif value == "--cflags" then
        showrepl = false
        local Table = require('table')
        local Path = require("path")
        local FS = require("fs")
        -- calculate includes relative to the binary
        local include_dir = Path.normalize(Path.resolve(
          Path.dirname(process.execPath),
          "../include/luvit"
        ))
        local cflags = {
          "-I" .. include_dir,
          "-I" .. Path.join(include_dir, "uv"),
          "-I" .. Path.join(include_dir, "luajit"),
          "-I" .. Path.join(include_dir, "http_parser"),
          "-D_LARGEFILE_SOURCE",
          "-D_FILE_OFFSET_BITS=64",
          "-Wall -Werror",
          "-fPIC"
        }
        print(Table.concat(cflags, " "))
      -- pkgconfig's --libs
      elseif value == "--libs" then
        showrepl = false
        local Table = require('table')
        local libs = {
          "-shared",
          -- TODO: "-L" .. lib_dir,
          "-lm"
        }
        if require('os').type() == "Darwin" then
          if false then -- TODO: check if 64 bit
            Table.insert(libs, "-pagezero_size 10000")
            Table.insert(libs, "-image_base 100000000")
          end
          Table.insert(libs, "-undefined dynamic_lookup")
        end
        print(Table.concat(libs, " "))
      elseif value:sub(1, 1) == "-" then
        usage()
        process.exit(1)
      else
        file = value
        showrepl = false
        state = "USERSPACE"
      end
    elseif state == "-e" then
      to_eval[#to_eval + 1] = value
      state = "BEGIN"
    elseif state == "USERSPACE" then
      args[#args + 1] = value
    end
  end

  if not (state == "BEGIN" or state == "USERSPACE") then
    usage()
    process.exit(1)
  end

  process.argv = args

  local repl = require('repl')

  if not (native.handleType(1) == "TTY") then
   usecolors = false
  end

  utils.loadColors (usecolors)

  for i, value in ipairs(to_eval) do
    repl.evaluateLine(value)
  end

  if file then
    if require('module').myloadfile(require('path').resolve(process.cwd(), file)) == nil then
      realAssert(nil, "file "..file.." not found")
    end
  elseif not (native.handleType(0) == "TTY") then
    process.stdin:on("data", function(line)
      repl.evaluateLine(line)
    end)
    process.stdin:readStart()
    native.run()
    process.exit(0)
  end

  if interactive or showrepl then
    repl.start()
  end

end, debug.traceback))

-- Start the event loop
native.run()

-- trigger exit handlers and exit cleanly
process.exit(process.exitCode or 0)
