#!/usr/bin/lua

local debug = false
local xdebug = false

local stack, while_stack, if_stack, commands = {}, {}, {}, {}

local executing = true
local look_for_end_while = false

-- basic stack manipulation
local function push( val )
    table.insert( stack, tostring( val ) )
end

local function pop()
    return table.remove( stack )
end

local function peek( n )
    return stack[ #stack  - n ]
end

-- returns true if every element of tab is true
-- uses i and v because a for loop with ipairs() was about 30% slower
local function multiand( tab )
    local i = 1
    local v = tab[ i ]
    while v ~= nil do
        if not v then return false end
        i = i + 1
        v = tab[ i ]
    end
    return true
end

-- executes the given function (in the form of an array of ops)
local function exec_ops( optable )
    local i = 1
    local v = optable[ i ]

    while v do
        if look_for_end_while then
            if v == keywords["repeat"] or
               v == keywords["until"]  then
                look_for_end_while = false
            end
            i = i + 1
        else
            if executing then
                local oldi = i
                i = v( i )
                if i == 0 then return end -- ;, exit
                while type( i ) == "string" do -- execute
                    if keywords[ i ] then
                        i = keywords[ i ]()
                    elseif userfuncs[ i ] then
                        i = userfuncs[ i ]()
                    else
                        if debug then
                            io.write( "invalid function name: ", i, "\n" )
                        end
                        break
                    end
                end
                if not i then i = oldi + 1 end
                if xdebug then
                    if optable.name then
                        io.write( optable.name, ": ", oldi, " (",
                                  ( commands[ optable.loc + i ] or "" ),
                                  "): { "
                                )
                        for _, v in ipairs( stack ) do
                            io.write( "\"", v, "\" " )
                        end
                        io.write( "}\n" )
                    end
                end
                if done then return end
            else
                if v == keywords["if"] or
                   v == keywords["else"] or
                   v == keywords["then"] then
                    v()
                end
                i = i + 1
            end
        end

        v = optable[ i ]
    end

    if debug then io.write( "unterminated function: ", optable.name, "\n" ) end
end

-- __call metamethod for ops
local function op_call( func )
    local d, t = func.data, type( func.data )
    if t == "table" then return exec_ops( d ) end
    if t == "string" then
        if string.sub( d, 1, 1 ) == "\"" then
            return push( string.sub( d, 2 ) )
        elseif keywords[ d ] then return keywords[ d ]()
        elseif userfuncs[ d ] then return userfuncs[ d ]()
        end
    end
    if t == "number" then return push( d ) end
end

-- user defined variable table, with some initial definitions
local uservars = { 
    ["pi"] = math.pi,
    ["e"] =  math.exp( 1 ),
}

-- built in keywords for the language
keywords = {
    ["+"] =        function()
                       push( pop() + pop() )
                   end
    ,
    ["-"] =        function()
                       push( -pop() + pop() )
                   end
    ,
    ["*"] =        function()
                       push( pop() * pop() )
                   end
    ,
    ["/"] =        function()
                       push( 1 / pop() * pop() )
                   end
    ,
    ["%"] =        function()
                       local num1, num2 = pop(), pop()
                       push( math.mod( num2, num1 ) )
                   end
    ,
    ["^"] =        function()
                       local num1, num2 = pop(), pop()
                       push( num2 ^ num1 )
                   end
    ,
    ["notify"] =   function()
                       io.write( pop(), "\n" )
                   end
    ,
    ["read"] =     function()
                       push( io.read() )
                   end
    ,
    ["pop"] =      function()
                       pop()
                   end
    ,
    ["dup"] =      function()
                       push( peek( 0 ) )
                   end
    ,
    ["swap"] =     function()
                       local val1, val2 = pop(), pop()
                       push( val1 )
                       push( val2 )
                   end
    ,
    ["over"] =     function()
                       push( peek( 1 ) )
                   end
    ,
    ["rotate"] =   function()
                       local num = tonumber( pop() )
                       if num > 0 then
                           push( table.remove( stack,
                                               #stack  - num + 1
                                             )
                               )
                       elseif num < 0 then
                           table.insert( stack, #stack  + num + 1,
                                         table.remove( stack )
                                       )
                       end
                   end
    ,
    ["pick"] =     function()
                       push( peek( pop() - 1 ) )
                   end
    ,
    ["="] =        function()
                       if tonumber( pop() ) == tonumber( pop() ) then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    ["!="] =       function()
                       if tonumber( pop() ) ~= tonumber( pop() ) then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    [">"] =        function()
                       if tonumber( pop() ) < tonumber( pop() ) then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    ["<"] =        function()
                       if tonumber( pop() ) > tonumber( pop() ) then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    [">="] =       function()
                       if tonumber( pop() ) <= tonumber( pop() ) then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    ["<="] =       function()
                       if tonumber( pop() ) >= tonumber( pop() ) then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    ["sin"] =      function()
                       push( math.sin( pop() ) )
                   end
    ,
    ["cos"] =      function()
                       push( math.cos( pop() ) )
                   end
    ,
    ["tan"] =      function()
                       push( math.tan( pop() ) )
                   end
    ,
    ["asin"] =     function()
                       push( math.asin( pop() ) )
                   end
    ,
    ["acos"] =     function()
                       push( math.acos( pop() ) )
                   end
    ,
    ["atan"] =     function()
                       push( math.atan( pop() ) )
                   end
    ,
    ["atan2"] =    function()
                       local num = pop()
                       push( math.atan2( pop(), num ) )
                   end
    ,
    ["abs"] =      function()
                       push( math.abs( pop() ) )
                   end
    ,
    ["ceil"] =     function()
                       push( math.ceil( pop() ) )
                   end
    ,
    ["floor"] =    function()
                       push( math.floor( pop() ) )
                   end
    ,
    ["rad"] =      function()
                       push( math.rad( pop() ) )
                   end
    ,
    ["deg"] =      function()
                       push( math.deg( pop() ) )
                   end
    ,
    ["log"] =      function()
                       push( math.log10( pop() ) )
                   end
    ,
    ["ln"] =       function()
                       push( math.log( pop() ) )
                   end
    ,
    ["max"] =      function()
                       push( math.max( pop(), pop() ) )
                   end
    ,
    ["min"] =      function()
                       push( math.min( pop(), pop() ) )
                   end
    ,
    ["and"] =      function() -- locals to avoid short circuiting
                       local num1, num2 = tonumber( pop() ), tonumber( pop() )
                       if num1 ~= 0 and num2 ~= 0 then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    ["or"] =       function() -- locals to avoid short circuiting
                       local num1, num2 = tonumber( pop() ), tonumber( pop() )
                       if num1 == 0 and num2 == 0 then push( 0 )
                       else push( 1 )
                       end
                   end
    ,
    ["not"] =      function()
                       if tonumber( pop() ) == 0 then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    ["strcat"] =   function()
                       local str = pop()
                       push( pop() .. str )
                   end
    ,
    ["spac"] =     function()
                       push( " " )
                   end
    ,
    ["empty"] =    function()
                       while peek( 0 ) do pop() end
                   end
    ,
    ["stack"] =    function()
                       for i = 0, #stack  - 1 do
                           io.write( peek( i ), "\n" )
                       end
                   end
    ,
    ["depth"] =    function()
                       push( #stack  )
                   end
    ,
    ["explode"] =  function()
                       local delim, str, count, ret = pop(), pop(), 0, {}
                       str = str .. delim
                       for match in string.gmatch( str, "(.-)" .. delim ) do
                           table.insert( ret, match )
                           count = count + 1
                       end
                       -- push in reverse order so they pop off in order
                       for i = #ret , 1, -1 do
                           push( ret[ i ] )
                       end
                       push( count )
                   end
    ,
    ["!"] =        function()
                       uservars[ pop() ] = pop()
                   end
    ,
    ["@"] =        function()
                       push( uservars[ pop() ] or 0 )
                   end
    ,
    ["unlet"] =    function()
                       uservars[ pop() ] = nil
                   end
    ,
    ["begin"] =    function( i )
                       table.insert( while_stack, { loc = i + 1, ifs = 0 } )
                   end
    ,
    ["while"] =    function( i )
                       if tonumber( pop() ) ~= 0 then
                           return i + 1
                       else
                           table.remove( while_stack )
                           look_for_end_while = true
                       end
                   end
    ,
    ["until"] =    function()
                       if tonumber( pop() ) == 0 then
                           return while_stack[ #while_stack  ].loc
                       else
                           table.remove( while_stack )
                       end
                   end
    ,
    ["repeat"] =   function()
                       return while_stack[ #while_stack  ].loc
                   end
    ,
    ["continue"] = function() -- different from repeat since break ignores it
                       return while_stack[ #while_stack  ].loc
                   end
    ,
    ["if"] =       function()
                       if pop() == '0' then table.insert( if_stack, false )
                       else table.insert( if_stack, true )
                       end
                       if #while_stack  > 0 then
                           while_stack[ #while_stack  ].ifs = 
                             while_stack[ #while_stack  ].ifs + 1
                       end

                       executing = multiand( if_stack )
                   end
    ,
    ["else"] =     function()
                       if_stack[ #if_stack  ] =
                         not if_stack[ #if_stack  ]
                       executing = multiand( if_stack )
                   end
    ,
    ["then"] =     function()
                       table.remove( if_stack )
                       if #while_stack  > 0 then
                           while_stack[ #while_stack  ].ifs =
                             while_stack[ #while_stack  ].ifs - 1
                       end
                       executing = multiand( if_stack )
                   end
    ,
    ["break"] =    function()
                      local ifs = while_stack[ #while_stack  ].ifs
                      while ifs > 0 do
                          table.remove( if_stack )
                          ifs = ifs - 1
                      end
                      table.remove( while_stack )
                      look_for_end_while = true
                   end
    ,
    ["address?"] = function()
                       local str = pop()
                       if userfuncs[ str ] or keywords[ str ] then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    ["int?"]     = function()
                       local num = tonumber( pop() )
                       if num and num == math.floor( num ) then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    ["number?"]  = function()
                       if tonumber( pop() ) then push( 1 )
                       else push( 0 )
                       end
                   end
    ,
    ["put"] =      function()
                       stack[ #stack  - pop() - 1 ] = pop()
                   end
    ,
    ["random"] =   function()
                       push( math.random( pop() ) )
                   end
    ,
    ["date"]     = function()
                       local date = os.date( "*t" )
                       push( date.year )
                       push( date.month )
                       push( date.day )
                   end
    ,
    ["execute"] =  function()
                       return pop()
                   end
    ,
    ["instr"] =    function()
                       local find = pop()
                       push( string.find( pop(), find, 1, true ) or 0 )
                   end
    ,
    ["rinstr"] =   function()
                       local last_found, found
                       local find, str = pop(), pop()
                       found = string.find( str, find, 1, true )
                       if not found then push( 0 ); return end
                       while found do
                           last_found = found + 1
                           found = string.find( str, find, last_found, true )
                       end
                       push( last_found - 1 )
                   end
    ,
    ["strcut"] =   function()
                       local num, str = pop(), pop()
                       push( string.sub( str, num + 1 ) )
                       push( string.sub( str, 1, num ) )
                   end
    ,
    ["stringpfx"] = function()
                        local pfx, str = pop(), pop()
                        if string.sub( str, 1, string.len( pfx ) ) == pfx then
                            push( 1 )
                        else
                            push( 0 )
                        end
                    end
    ,
    ["strcmp"] =   function()
                        local str1, str2 = pop(), pop()
                        local i = 1
                        while string.byte( str1, i ) ==
                              string.byte( str2, i ) do
                            if not string.byte( str1, i ) then
                                push( 0 )
                                return
                            end
                            i = i + 1
                        end
                        local char1 = string.byte( str1, i )
                        local char2 = string.byte( str2, i )
                        if char1 and char2 then
                            push( char1 - char2 )
                        else 
                            push( char1 or -char2 )
                        end
                    end
    ,
    ["strncmp"] =  function()
                       local count, str1, str2 = pop(), pop(), pop()
                       local i = 1
                       for j = 1, count - 1 do
                           if string.byte( str1, i ) ~=
                              string.byte( str2, i ) then
                               break
                           end
                           if not string.byte( str1, i ) then
                               push( 0 )
                               return
                           end
                           i = i + 1
                       end
                       local char1 = string.byte( str1, i )
                       local char2 = string.byte( str2, i )
                       if char1 and char2 then
                           push( char1 - char2 )
                       else 
                           push( char1 or -char2 )
                       end
                   end
    ,
    ["subst"] =    function()
                       local old, new, str = pop(), pop(), pop()
                       push( string.gsub( str, old, new ) )
                   end
    ,
    ["strlen"] =   function()
                       push( string.len( pop() ) )
                   end
    ,
    ["tolower"] =  function()
                       push( string.lower( pop() ) )
                   end
    ,
    ["toupper"] =  function()
                       push( string.upper( pop() ) )
                   end
    ,
    ["striplead"] = function()
                        push( string.gsub( pop(), "^%s*", "" ) )
                    end
    ,
    ["striptail"] = function()
                        push( string.gsub( pop(), "%s*$", "" ) )
                    end
    ,
    ["systime"] =  function()
                       push( os.time() )
                   end
    ,
    ["time"] =     function()
                       local date = os.date( "*t" )
                       push( date.sec )
                       push( date.min )
                       push( date.hour )
                   end
    ,
    ["timefmt"] =  function()
                       local time = pop()
                       push( os.date( pop(), time ) )
                   end
    ,
    ["timesplit"] = function()
                        local date = os.date( "*t", pop() )
                        push( date.sec )
                        push( date.min )
                        push( date.hour )
                        push( date.day )
                        push( date.month )
                        push( date.year )
                        push( date.wday )
                        push( date.yday )
                    end
    ,
    ["debug"] =    function()
                       debug = not debug
                   end
    ,
    ["xdebug"] =   function()
                       xdebug = not xdebug
                   end
    ,
    [";"] =        function()
                       return 0
                   end
    ,
    ["exit"] =     function()
                       return 0
                   end
    ,
    [";;"] =       function()
                       done = true
                   end
}

-- user defined functions, with some initial definitions
userfuncs = {
    ["wait"] =      setmetatable( { data = { keywords["read"],
                                             keywords["pop"],
                                             keywords[";"]
                                           },
                                    name = "wait"
                                  }, { __call = op_call } )
    ,
    ["spacecat"] =  setmetatable( { data = { keywords["spac"],
                                             keywords["swap"],
                                             keywords["strcat"],
                                             keywords["strcat"],
                                             keywords[";"]
                                           },
                                    name = "spacecat"
                                  }, { __call = op_call } )
    ,
    ["incr"] =      setmetatable( { data = { setmetatable( { data = 1 },
                                                           { __call = op_call }
                                                         ),
                                             keywords["+"],
                                             keywords[";"]
                                           },
                                    name = "incr"
                                  }, { __call = op_call } )
    ,
    ["decr"] =      setmetatable( { data = { setmetatable( { data = 1 },
                                                           { __call = op_call }
                                                         ),
                                             keywords["-"],
                                             keywords[";"]
                                           },
                                    name = "decr"
                                  }, { __call = op_call } )
    ,
    ["root"] =      setmetatable( { data = { setmetatable( { data = 1 },
                                                           { __call = op_call }
                                                         ),
                                             keywords["swap"],
                                             keywords["/"],
                                             keywords["^"],
                                             keywords[";"]
                                           },
                                    name = "root"
                                  }, { __call = op_call } )
    ,
    ["sqrt"] =      setmetatable( { data = { setmetatable( { data = .5 },
                                                           { __call = op_call }
                                                         ),
                                             keywords["^"],
                                             keywords[";"]
                                           },
                                    name = "sqrt"
                                  }, { __call = op_call } )
    ,
    ["csc"] =       setmetatable( { data = { keywords["sin"],
                                             setmetatable( { data = 1 },
                                                           { __call = op_call }
                                                         ),
                                             keywords["swap"],
                                             keywords["/"],
                                             keywords[";"]
                                           },
                                    name = "csc"
                                  }, { __call = op_call } )
    ,
    ["sec"] =       setmetatable( { data = { keywords["cos"],
                                             setmetatable( { data = 1 },
                                                           { __call = op_call }
                                                         ),
                                             keywords["swap"],
                                             keywords["/"],
                                             keywords[";"]
                                           },
                                    name = "sec"
                                  }, { __call = op_call } )
    ,
    ["cot"] =       setmetatable( { data = { keywords["tan"],
                                             setmetatable( { data = 1 },
                                                           { __call = op_call }
                                                         ),
                                             keywords["swap"],
                                             keywords["/"],
                                             keywords[";"]
                                           },
                                    name = "cot"
                                  }, { __call = op_call } )
    ,
    ["acsc"] =      setmetatable( { data = { setmetatable( { data = 1 },
                                                           { __call = op_call }
                                                         ),
                                             keywords["swap"],
                                             keywords["/"],
                                             keywords["asin"],
                                             keywords[";"]
                                           },
                                    name = "acsc"
                                  }, { __call = op_call } )
    ,
    ["asec"] =      setmetatable( { data = { setmetatable( { data = 1 },
                                                           { __call = op_call }
                                                         ),
                                             keywords["swap"],
                                             keywords["/"],
                                             keywords["acos"],
                                             keywords[";"]
                                           },
                                    name = "asec"
                                  }, { __call = op_call } )
    ,
    ["acot"] =      setmetatable( { data = { setmetatable( { data = 1 },
                                                           { __call = op_call }
                                                         ),
                                             keywords["swap"],
                                             keywords["/"],
                                             keywords["atan"],
                                             keywords[";"]
                                           },
                                    name = "acot"
                                  }, { __call = op_call } )
    ,
    ["instring"] =  setmetatable( { data = { keywords["tolower"],
                                             keywords["swap"],
                                             keywords["tolower"],
                                             keywords["swap"],
                                             keywords["instr"],
                                             keywords[";"]
                                           },
                                    name = "instring"
                                  }, { __call = op_call } )
    ,
    ["rinstring"] = setmetatable( { data = { keywords["tolower"],
                                             keywords["swap"],
                                             keywords["tolower"],
                                             keywords["swap"],
                                             keywords["rinstr"],
                                             keywords[";"]
                                           },
                                    name = "rinstring"
                                  }, { __call = op_call } )
    ,
    ["stringcmp"] = setmetatable( { data = { keywords["tolower"],
                                             keywords["swap"],
                                             keywords["tolower"],
                                             keywords["swap"],
                                             keywords["strcmp"],
                                             keywords[";"]
                                           },
                                    name = "stringcmp"
                                  }, { __call = op_call } )
    ,
    ["strip"] =     setmetatable( { data = { keywords["striplead"],
                                             keywords["striptail"],
                                             keywords[";"]
                                           },
                                    name = "strip"
                                  }, { __call = op_call } )
    ,
    ["rot"] =      setmetatable( { data = { setmetatable( { data = 3 },
                                                          { __call = op_call }
                                                        ),
                                            keywords["rotate"],
                                            keywords[";"]
                                          },
                                   name = "rot"
                                 }, { __call = op_call } )
}

local from_file, continuing = false, false
local script_file = io.stdin
if arg[ 1 ] then 
    -- use explicit file descriptors so that read will work properly in files
    script_file = assert( io.open( arg[ 1 ], "r" ) )
    from_file = true
end

local whiles, ifs = 0, 0

-- main program loop
done = false
while not done do
    if not from_file then
        if not continuing then io.write( "> " )
        else io.write( ">> " )
        end
    end

    local exec_str
    if from_file then
        exec_str = script_file:read( "*a" )
    else
        if continuing then
            exec_str = script_file:read()
        else
            exec_str = ": main " .. script_file:read()
        end
    end

    -- split the input string (add stuff from args here for quote parsing)
    local comment = false
    for word in string.gmatch( exec_str, "%S+" ) do
        if word == "begin"  then whiles = whiles + 1 end
        if word == "repeat" then whiles = whiles - 1 end
        if word == "until"  then whiles = whiles - 1 end
        if word == "if"     then ifs    = ifs    + 1 end
        if word == "then"   then ifs    = ifs    - 1 end

        if word == "(" then comment = true end
        if not comment then table.insert( commands, word ) end
        if word == ")" then comment = false end
        --io.stdout:write( word .. ": " .. whiles .. " " .. ifs .. " \n" )
    end

    if ifs ~= 0 or whiles ~= 0 then
        continuing = true
    else
        continuing = false
        -- no need to test for from_file here since extra ;s are ignored
        table.insert( commands, ";" )
    end

    if not continuing then -- don't execute if command list is incomplete
        local current_op_table = setmetatable( {}, { __call = op_call } )

        -- turn the tokens into opcodes
        local is_funcname = false
        for i, v in ipairs( commands ) do
            if is_funcname then
                current_op_table.name = v
                current_op_table.loc = i - 1
                userfuncs[ v ] = true -- allow recursive definitions
                is_funcname = false
            elseif v == ":" then
                if current_op_table.name then
                    -- recursion. this stores a table reference, so multiple
                    -- levels of recursion work
                    for i, v in ipairs( current_op_table ) do
                        if v == current_op_table.name then
                            current_op_table[ i ] =
                              setmetatable( { data = current_op_table },
                                            { __call = op_call } )
                        end
                    end

                    userfuncs[ current_op_table.name ] =
                              setmetatable( { data = current_op_table },
                                            { __call = op_call } )
                end
                current_op_table = {}
                is_funcname = true
            -- this allows stray - signs within decimals (like 3.14-15) fix?
            elseif string.find( v, "^%-?%d*%.?%d+[eE]?%-?%d*$" ) then
                table.insert( current_op_table,
                              setmetatable( { data = tonumber( v ) },
                                            { __call = op_call }
                                          )
                            )
            elseif string.find( v, "^\".+" ) then
                table.insert( current_op_table, 
                              setmetatable( { data = v }, { __call = op_call } )
                            )
            elseif keywords[ v ] then
                table.insert( current_op_table, keywords[ v ] )
            elseif type( userfuncs[ v ] ) == "boolean" then
                table.insert( current_op_table, v ) -- string for recursion
            elseif type( userfuncs[ v ] ) == "table" then
                table.insert( current_op_table, userfuncs[ v ] )
            else
                if debug then io.write( "unknown word: ", v, "\n" ) end
                break
            end
        end

        -- grab the last function definition
        userfuncs[ current_op_table.name ] = current_op_table

        -- execute the main function
        if not done then exec_ops( userfuncs.main ) end

        if debug then
            io.write( "{ " )
            for _, v in ipairs( stack ) do
                io.write( "\"", v, "\" " )
            end
            io.write( "}\n" )
        end

        commands = {}
    end
    
    -- we read the whole file at once, so looping won't get us anymore text
    if from_file then break end
end
