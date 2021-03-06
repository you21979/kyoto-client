kt = require '../lib/index'
util = require 'util'
testCase = require('nodeunit').testCase
fs = require 'fs'

testDb = "test"
alternateDb = "test2"
db = new kt.Db testDb
db.open('localhost', 1979)

dbClear = (callback) ->
  db.clear (error, output) ->
    callback()

module.exports =
  'Cursor with a starting key': testCase
    setUp: (callback) ->
      db.clear (error, output) =>
        db.set 'cursor-test', "Cursor\tValue", (error) =>
          db.getCursor 'cursor-test', (error, cursor) =>
            throw error if error?
            @cursor = cursor
            callback()

    tearDown: (callback) ->
      @cursor.delete ->
        callback()

    get:
      'returns the key and value': (test) ->
        test.expect 3
        @cursor.get (error, output) ->
          test.ifError error
          test.equal output.key.toString('utf8'), "cursor-test"
          test.equal output.value.toString('utf8'), "Cursor\tValue"
          test.done()

      'handles base64 encoded responses': (test) ->
        test.expect 2
        fs.readFile "#{__dirname}/../doc/output/favicon.ico", (error, data) =>
          test.ifError error
          # Storing a predompinently binary value triggers a base64 response
          # from the server.
          db.set 'test', data, (error) =>
            @cursor.jump 'test', =>
              @cursor.get (error, output) ->
                # The base64 package returns binary strings when it decodes
                # convert the source data to the same to make the two values
                # comparable.
                dataString = data.toString 'binary'
                test.equal output.value, dataString
                test.done()

    remove:
      'removes the record': (test) ->
        test.expect 2
        @cursor.remove (error, output) ->
          test.ifError error

          db.get 'cursor-test', (error, value) ->
            test.ok value == null
            test.done()

    each:
      'yields records on each iteration': (test) ->
        test.expect 2

        runTest = =>
          results = []
          @cursor.jump (error) =>
            @cursor.each (error, output) ->
              if output.key?
                results.push [output.key, output.value]
              else
                test.ifError error
                test.deepEqual [
                    [ '1', 'One' ]
                    [ '2', 'Two' ]
                    [ 'cursor-test', 'Cursor\tValue' ]
                  ],
                  results
                test.done()

        db.set '1', 'One', (error, output) ->
          db.set '2', 'Two', (error, output) ->
            runTest()

  'Cursor without a starting key': testCase
    setUp: (callback) ->
      @records =
        'first': "Cursor\tValue"
        'last': "At the end"
      db.clear (error, output) =>
        db.setBulk @records, (error) =>
          db.getCursor (error, cursor) =>
            @cursor = cursor
            callback()

    tearDown: (callback) ->
      @cursor.delete ->
        callback()

    jump:
      'allows traversal from the first record': (test) ->
        test.expect 2
        @cursor.jump (error, output) =>
          test.ifError error
          @cursor.getKey (error, output) ->
            test.equal output.key.toString('utf8'), "first"
            test.done()

      'step goes to the next record': (test) ->
        test.expect 1
        @cursor.jump (error, output) =>
          @cursor.step (error, output) =>
            @cursor.getKey (error, output) ->
              test.equal output.key.toString('utf8'), "last"
              test.done()

    jumpBack:
      'allows traversal from the last record': (test) ->
        test.expect 2
        @cursor.jumpBack (error, output) =>
          test.ifError error
          @cursor.getKey (error, output) ->
            test.equal output.key.toString('utf8'), "last"
            test.done()

      'stepBack goes to the previous record': (test) ->
        test.expect 1
        @cursor.jumpBack (error, output) =>
          @cursor.stepBack (error, output) =>
            @cursor.get (error, output) ->
              test.equal output.key.toString('utf8'), "first"
              test.done()

    setValue:
      'sets the value of the current record': (test) ->
        test.expect 2
        @cursor.setValue "New Value", (error, output) =>
          test.ifError error
          @cursor.getValue (error, output) ->
            test.equal output.value.toString('utf8'), "New Value"
            test.done()

      'allows stepping to the next record': (test) ->
        test.expect 2
        @cursor.setValue "New Value", true, (error, output) =>
          test.ifError error
          @cursor.getKey (error, output) ->
            test.equal output.key.toString('utf8'), 'last'
            test.done()

      'accept a Buffer as the value': (test) ->
        test.expect 2
        buffer = new Buffer("Some Value", 'ascii')
        @cursor.setValue buffer, (error, output) =>
          test.ifError error
          @cursor.getValue (error, output) ->
            test.equal output.value.toString('ascii'), "Some Value"
            test.done()

    remove:
      'removes the record': (test) ->
        test.expect 2
        @cursor.remove (error, output) ->
          test.ifError error

          db.get 'cursor-test', (error, value) ->
            test.ok value == null
            test.done()

    getKey:
      'returns the key of the current record': (test) ->
        test.expect 1
        @cursor.getKey (error, output) ->
          test.equal output.key.toString('utf8'), "first"
          test.done()

      'allows stepping to the next record': (test) ->
        test.expect 2
        @cursor.getKey true, (error, output) =>
          test.ifError error
          @cursor.get (error, output) ->
            test.equal output.key.toString('utf8'), 'last'
            test.done()

    getValue:
      'returns the value of the current record': (test) ->
        test.expect 1
        @cursor.getValue (error, output) ->
          test.equal output.value.toString('utf8'), "Cursor\tValue"
          test.done()

      'allows stepping to the next record': (test) ->
        test.expect 2
        @cursor.getValue true, (error, output) =>
          test.ifError error
          @cursor.get (error, output) ->
            test.equal output.key.toString('utf8'), 'last'
            test.done()

    get:
      'returns the key and value of the current record': (test) ->
        test.expect 2
        @cursor.get (error, output) ->
          test.equal output.key.toString('utf8'), "first"
          test.equal output.value.toString('utf8'), "Cursor\tValue"
          test.done()

      'allows stepping to the next record': (test) ->
        test.expect 2
        @cursor.get true, (error, output) =>
          test.ifError error
          @cursor.get (error, output) ->
            test.equal output.key.toString('utf8'), 'last'
            test.done()

    each:
      'yields records on each iteration': (test) ->
        test.expect 2

        runTest = =>
          results = []
          @cursor.jump '1', (error) =>
            @cursor.each (error, output) ->
              if output.key?
                results.push [output.key, output.value]
              else
                test.ifError error
                test.deepEqual [
                    [ '1', 'One' ]
                    [ '2', 'Two' ]
                    [ 'first', 'Cursor\tValue' ]
                    [ 'last', 'At the end' ]
                  ],
                  results
                test.done()

        db.set '1', 'One', (error, output) ->
          db.set '2', 'Two', (error, output) ->
            runTest()

  'Cursor for an alternate database': testCase
    setUp: (callback) ->
      @records =
        'first': "Cursor\tValue"
        'last': "At the end"

      # Clear both databases
      db.clear (error, output) =>
        console.log "clear default"
        throw error if error?
        db.clear {database: alternateDb}, (error, output) =>
          throw error if error?
          db.setBulk @records, {database: alternateDb}, (error) =>
            throw error if error?
            db.getCursor null, {database: alternateDb}, (error, cursor) =>
              throw error if error?
              console.log "getCursor"
              @cursor = cursor
              callback()

    tearDown: (callback) ->
      @cursor.delete ->
        callback()

    jump:
      'allows traversal from the first record': (test) ->
        test.expect 2
        @cursor.jump (error, output) =>
          test.ifError error
          @cursor.getKey (error, output) ->
            test.equal output.key.toString('utf8'), "first"
            test.done()

      'step goes to the next record': (test) ->
        test.expect 1
        @cursor.jump (error, output) =>
          @cursor.step (error, output) =>
            @cursor.getKey (error, output) ->
              test.equal output.key.toString('utf8'), "last"
              test.done()

    jumpBack:
      'allows traversal from the last record': (test) ->
        test.expect 2
        @cursor.jumpBack (error, output) =>
          test.ifError error
          @cursor.getKey (error, output) ->
            test.equal output.key.toString('utf8'), "last"
            test.done()

      'stepBack goes to the previous record': (test) ->
        test.expect 1
        @cursor.jumpBack (error, output) =>
          @cursor.stepBack (error, output) =>
            @cursor.get (error, output) ->
              test.equal output.key.toString('utf8'), "first"
              test.done()

    setValue:
      'sets the value of the current record': (test) ->
        test.expect 2
        @cursor.setValue "New Value", (error, output) =>
          test.ifError error
          @cursor.getValue (error, output) ->
            test.equal output.value.toString('utf8'), "New Value"
            test.done()

      'allows stepping to the next record': (test) ->
        test.expect 2
        @cursor.setValue "New Value", true, (error, output) =>
          test.ifError error
          @cursor.getKey (error, output) ->
            test.equal output.key.toString('utf8'), 'last'
            test.done()

      'accept a Buffer as the value': (test) ->
        test.expect 2
        buffer = new Buffer("Some Value", 'ascii')
        @cursor.setValue buffer, (error, output) =>
          test.ifError error
          @cursor.getValue (error, output) ->
            test.equal output.value.toString('ascii'), "Some Value"
            test.done()

    remove:
      'removes the record': (test) ->
        test.expect 2
        @cursor.remove (error, output) ->
          test.ifError error

          db.get 'cursor-test', (error, value) ->
            test.ok value == null
            test.done()

    getKey:
      'returns the key of the current record': (test) ->
        test.expect 1
        @cursor.getKey (error, output) ->
          test.equal output.key.toString('utf8'), "first"
          test.done()

      'allows stepping to the next record': (test) ->
        test.expect 2
        @cursor.getKey true, (error, output) =>
          test.ifError error
          @cursor.get (error, output) ->
            test.equal output.key.toString('utf8'), 'last'
            test.done()

    getValue:
      'returns the value of the current record': (test) ->
        test.expect 1
        @cursor.getValue (error, output) ->
          test.equal output.value.toString('utf8'), "Cursor\tValue"
          test.done()

      'allows stepping to the next record': (test) ->
        test.expect 2
        @cursor.getValue true, (error, output) =>
          test.ifError error
          @cursor.get (error, output) ->
            test.equal output.key.toString('utf8'), 'last'
            test.done()

    get:
      'returns the key and value of the current record': (test) ->
        test.expect 2
        @cursor.get (error, output) ->
          test.equal output.key.toString('utf8'), "first"
          test.equal output.value.toString('utf8'), "Cursor\tValue"
          test.done()

      'allows stepping to the next record': (test) ->
        test.expect 2
        @cursor.get true, (error, output) =>
          test.ifError error
          @cursor.get (error, output) ->
            test.equal output.key.toString('utf8'), 'last'
            test.done()

    each:
      'yields records on each iteration': (test) ->
        test.expect 2

        runTest = =>
          results = []
          @cursor.jump '1', {database: alternateDb}, (error) =>
            @cursor.each (error, output) ->
              if output.key?
                results.push [output.key, output.value]
              else
                test.ifError error
                test.deepEqual [
                    [ '1', 'One' ]
                    [ '2', 'Two' ]
                    [ 'first', 'Cursor\tValue' ]
                    [ 'last', 'At the end' ]
                  ],
                  results
                test.done()

        db.set '1', 'One', {database: alternateDb}, (error, output) ->
          db.set '2', 'Two', {database: alternateDb}, (error, output) ->
            runTest()
