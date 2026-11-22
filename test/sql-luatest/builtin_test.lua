local server = require('luatest.server')
local t = require('luatest')

local g = t.group()

g.before_all(function(cg)
    cg.server = server:new({alias = 'master'})
    cg.server:start()
end)

g.after_all(function(cg)
    cg.server:drop()
end)

--
-- ghs-160: The built-in REPLACE function threw a segmentation fault if
-- the length of the first argument was less than the length of the second.
--
g.test_segfault_in_replace = function(cg)
    cg.server:exec(function()
        local res = box.execute([[SELECT REPLACE('', 'ab', 'xy');]])
        t.assert_equals(res.rows, {{''}})
        res = box.execute([[SELECT REPLACE('a', 'ab', 'xy');]])
        t.assert_equals(res.rows, {{'a'}})
    end)
end

--
-- ghs-161: The PRINTF built-in function could have an integer overflow.
--
g.test_integer_overflow_in_printf = function(cg)
    cg.server:exec(function()
        local exp = "Failed to execute SQL statement: string or blob too big"
        local sql = [[SELECT LENGTH(PRINTF('%2200000000s', 'a'));]]
        local _, err = box.execute(sql)
        t.assert_equals(err.message, exp)
    end)
end

--
-- gh-13682: SUBSTRING(s FROM start [FOR length]) is the standard form of
-- SUBSTR(s, start[, length]).
--
g.test_substring_from = function(cg)
    cg.server:exec(function()
        local res = box.execute([[SELECT SUBSTRING('abcdef' FROM 2);]])
        t.assert_equals(res.rows, {{'bcdef'}})
        t.assert_equals(res.metadata[1].type, 'string')
        res = box.execute([[SELECT SUBSTRING('abcdef' FROM 2 FOR 3);]])
        t.assert_equals(res.rows, {{'bcd'}})
        res = box.execute([[SELECT substring('abcdef' from 2 for 3);]])
        t.assert_equals(res.rows, {{'bcd'}})
    end)
end

g.test_substring_from_varbinary = function(cg)
    cg.server:exec(function()
        local sql = [[SELECT SUBSTRING(x'010203' FROM 2 FOR 1) = x'02',
                             TYPEOF(SUBSTRING(x'010203' FROM 2));]]
        t.assert_equals(box.execute(sql).rows, {{true, 'varbinary'}})
    end)
end

g.test_substring_from_start_before_string = function(cg)
    cg.server:exec(function()
        local res = box.execute([[SELECT SUBSTRING('abcdef' FROM 0 FOR 3);]])
        t.assert_equals(res.rows, {{'ab'}})
        res = box.execute([[SELECT SUBSTRING('abcdef' FROM -1 FOR 3);]])
        t.assert_equals(res.rows, {{'a'}})
    end)
end

g.test_substring_from_null = function(cg)
    cg.server:exec(function()
        local sql = [[SELECT SUBSTRING(NULL FROM 2), SUBSTRING('abc' FROM NULL),
                             SUBSTRING('abc' FROM 2 FOR NULL);]]
        t.assert_equals(box.execute(sql).rows, {{nil, nil, nil}})
    end)
end

g.test_substring_from_expression_operands = function(cg)
    cg.server:exec(function()
        local sql = [[SELECT SUBSTRING('abc' || 'def' FROM 1 + 1 FOR 5 - 2);]]
        t.assert_equals(box.execute(sql).rows, {{'bcd'}})
        sql = [[SELECT SUBSTRING(? FROM ? FOR ?);]]
        t.assert_equals(box.execute(sql, {'abcdef', 3, 2}).rows, {{'cd'}})
    end)
end

g.test_substring_from_negative_length = function(cg)
    cg.server:exec(function()
        local _, exp = box.execute([[SELECT SUBSTR('abcdef', 2, -1);]])
        t.assert_not_equals(exp, nil)
        local sql = [[SELECT SUBSTRING('abcdef' FROM 2 FOR -1);]]
        local _, err = box.execute(sql)
        t.assert_equals(err.message, exp.message)
    end)
end

--
-- gh-13682: SUBSTRING is a reserved keyword.
--
g.test_substring_is_reserved = function(cg)
    cg.server:exec(function()
        local sql = [[CREATE TABLE t (SUBSTRING INT PRIMARY KEY);]]
        local _, err = box.execute(sql)
        t.assert_str_contains(err.message, "keyword 'SUBSTRING' is reserved")
        sql = [[CREATE TABLE t ("SUBSTRING" INT PRIMARY KEY);]]
        t.assert_equals(box.execute(sql), {row_count = 1})
        box.execute([[DROP TABLE t;]])
    end)
end
