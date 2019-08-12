--*****************************************************************************
--* Tjos 4gl library provides an interface to an xml based key value store    *
--* that can be read in a run time.  This provides a means to update config.  *
--* uration settings without recompiling the source code.                     *
--*                                                                           *
--* The format of the xml file is based upon the java properties file spec.   *
--* Here is the DTD                                                           *
--* <?xml version="1.0" encoding="UTF-8"?>                                    *
--* <!-- DTD for properties -->                                               *
--* <!ELEMENT properties ( comment?, entry* ) >                               *
--* <!ATTLIST properties version CDATA #FIXED "1.0">                          *
--* <!ELEMENT comment (#PCDATA) >                                             *
--* <!ELEMENT entry (#PCDATA) >                                               *
--* <!ATTLIST entry key CDATA #REQUIRED>                                      *
--*                                                                           *
--* Sample based upon the above DTD                                           *
--*                                                                           *
--* <?xml version="1.0" encoding="UTF-8" standalone="no"?>                    *
--* <!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">     *
--* <properties>                                                              *
--*    <comment>This is a comment</comment>                                   *
--*    <entry key="foo_key">foo_value</entry>                                 *
--*    <entry key="bar_key">bar_value</entry>                                 *
--* </properties>                                                             *
--*    Date     Developer   Changes                                           *
--* ----------  ----------  -------                                           *
--* 05/01/2017 DeanT        Initial version                                   *
--*****************************************************************************
import security
import xml
import base
#The debug enable the test main method.  If deploying as a library
# it must be commented out.
#&define DEBUG
Globals
    CONSTANT G_HASH_ALGO = "MD5"
    CONSTANT MAX_HASHLIST_LENGTH = 255
    CONSTANT G_KEY_VAL_SEPARATOR = ":"
    CONSTANT LIB_PROPERTIES_LOG = "lib_properties.log"
end globals
    public type property record
        key string
        ,value string
    end record
    
    
    define 
        value_hashlist dynamic array with dimension 2 of property
        ,dgst security.Digest
        ,seed String

&ifdef DEBUG
main
    define result string
    define xml_file, xml string
    define key_list dynamic array of string
    , i int
    call startlog("lib_properties.log")
    call errorlog("Starting debug test")
    --call set_property("FOO","FOOVALUE")
    --call set_property("BAR","BARVALUE")
    
    --let result = "FOO:",get_property("FOO"), " ","BAR:",get_property("BAR")
    
    display result
    
    --let xml = '<?xml version="1.0" encoding="UTF-8" standalone="no"?><!DOCTYPE properties SYSTEM --"http://java.sun.com/dtd/properties.dtd"><properties><comment>This is a --comment.</comment><entry key="foo_key">foo_value</entry><entry --key="bar_key">bar_value</entry></properties>'
    --let xml_file = "lib_properties.xml"
    let xml_file = "timecd_ws_prop.xml"
    call value_hashlist.clear()
    --call load_xml_string(xml)
    call load_xml_file(xml_file)
    --let result = "foo_key:",get_property("foo_key"), " ","bar_key:",get_property("bar_key")
    --display result
    --call get_keys() returning key_list
    --for i = 1 to key_list.getLength()
    --    display key_list[i]
    --end for
    
end main

&endif
{
    Loads the properties based upon an xml file
}
function load_xml_file(filename)
    define 
        filename string
        ,doc xml.DomDocument
        ,properties_tree xml.DomDocument
    call startlog(LIB_PROPERTIES_LOG)
    let properties_tree = xml.DomDocument.create()
    display "Loading property file ", filename
    call errorlog("Loading property file " || filename)
    call properties_tree.load(filename)
    call update_key_value_pairs(properties_tree)
end function

{
    Loads the properties based upon an XML string
}
function load_xml_string(xmlString)
    define 
        xmlString string
        ,properties_tree xml.DomDocument
    call startlog(LIB_PROPERTIES_LOG)
    let properties_tree = xml.DomDocument.createDocument(xmlString)
    call update_key_value_pairs(properties_tree)
end function

{
    Updates the key/value lists based upon the passed document string
    any prior key values will be replaced
}
function update_key_value_pairs(properties_tree)
    define
        properties_tree xml.DomDocument
        ,root xml.DomNode
        ,prop_list xml.DomNodeList
        ,prop_item xml.DomNode
        ,value_node xml.DomNode
        
        ,i int
        ,key, value string
    #For each properties element in tree
    #Get key value pair and insert into hash table if it exists
        let root = properties_tree.getDocumentElement()
        call errorlog("Updating properties hash table")
        --call errorlog("Property contents:"|| root.toString())
        let prop_list = root.getElementsByTagName("entry")
        for i = 1 to prop_list.getCount()
            let prop_item = prop_list.getItem(i)
            let key = prop_item.getAttribute("key")
            let value_node = prop_item.getFirstChild()
            if value_node is null then
                let value = " "
            else
                let value = value_node.toString()
            end if
            --call errorlog("Setting property value " || key || ":" || value)
            
            call set_property(key,value)
        end for
end function
{
    Gets the value associated with the passed key, otherwise
    return null
}
function get_property(key)
    define key, value string
    ,prop property
    ,hash_int int
    ,index int
    ,found boolean
    let found = false
    let hash_int = get_key_hash(key)
    if value_hashlist[hash_int].getLength() > 0 then
        for index = 1 to value_hashlist[hash_int].getLength()
            if value_hashlist[hash_int][index].key == key then
                let found = true
                let value = value_hashlist[hash_int][index].value
            end if
        end for
    end if
    if found then
        return value
    else
        display 'No property found for this key: ' || key || " add this setting to the to the properties file."
        call errorlog('No property found for this key: ' || key || " add this setting to the to the properties file. Exiting ...")
        call errorlog("Exiting program... " || ARG_VAL(0)) 
        exit program -1
    end if
    return value
end function

{
    Gets the value associated with the property and returns
    it as an array.  Assumes the value is a comma separated
    list. Commas can be escaped with a backslash
}
function get_property_list(key)
    define 
        key,value string
        ,value_list dynamic array of string
        ,st_token base.StringTokenizer
        
    let value = get_property(key)
    let st_token = base.StringTokenizer.createExt(value,",","\\",false)
    while st_token.hasMoreTokens() 
        let value_list[value_list.getLength()+1] = st_token.nextToken()
    end while
    return value_list
end function
    

{
    Gets the property if it exists otherwise
    returns default value.  
}
function get_property_default(key,default)
    define 
    value string
    ,key string
    ,default string
    let value = get_property(key)
    if value is null or value == " " then
        return default
    end if
    return value
end function
{
    Sets the value assosiated with the key.
}
function set_property(key,value)
    define key, value string
    ,new_prop property
    ,curr_prop property
    , hash_int, index int
    ,found boolean
   
    let hash_int = get_key_hash(key)
    call errorlog("Hash key -" || key || G_KEY_VAL_SEPARATOR ||hash_int)
    let found = false
    #update property value if found
    if value_hashlist[hash_int].getLength() > 0 then
        for index = 1 to value_hashlist[hash_int].getLength()
            if value_hashlist[hash_int][index].key = key then
                let value_hashlist[hash_int][index].value = value
                let found = true
                exit for
            end if
        end for
    end if
    #if not found then create new entry
    if not found then
        call value_hashlist[hash_int].appendElement()
        let index = value_hashlist[hash_int].getLength()
        let value_hashlist[hash_int][index].key = key
        let value_hashlist[hash_int][index].value = value
    end if
    
    
end function

{
    Returns an array containing all the key values.  This should be called with
    the call get_keys() returning variable syntax
}
function get_keys()
    define x, y int
    ,key_list dynamic array of string
    for x = 1 to value_hashlist.getLength()
        for y = 1 to value_hashlist[x].getLength()
            if  value_hashlist[x][y].key is not null then
                let key_list[key_list.getLength() + 1] = value_hashlist[x][y].key
            end if
        end for
    end for
    return key_list
end function
{
    Returns an index value based upon the key
}
function get_key_hash(key)
    define key string
    , hash string
    ,hashInt
    ,i int
    if seed is null then
        let seed = security.RandomGenerator.CreateUUIDString()
    end if
    let hash = security.Digest.CreateDigestString(key,null)
    let hashInt = 0
    for i = 1 to hash.getLength()
        let hashInt = hashInt + (ord(hash.getCharAt(i))*i)
    end for
    let hashInt = (hashInt mod MAX_HASHLIST_LENGTH) + 1
    return hashInt
end function

{Utility function to initialize the paycode-classcode pair list}
function get_key_value_list(prop_key)
    define
        prop_key string
        ,key_value_list_str dynamic array of string
        ,item_str string
        ,key_value_list dynamic array of property
        ,idx int
        ,split_pos int
    
    let key_value_list_str = get_property_list(prop_key)
    for idx = 1 to key_value_list_str.getLength()
        let item_str = key_value_list_str[idx]
        let split_pos = item_str.getIndexOf(G_KEY_VAL_SEPARATOR,1)
        let key_value_list[idx].key = item_str.subString(1,(split_pos-1))
        let key_value_list[idx].value = item_str.subString((split_pos+1),item_str.getLength())
    end for
    return key_value_list
end function

{
    Utility method that acceps a template, an anchor and substitutes
    the sub value where found in the template string.  Used for string templates
    such as substitute_token("cat <file_name>","<file_name>","hello") 
    In this case all occurances if file_name will be replaced with the hello
    value specified in the third argument
}
function substitute_token(template_str,anchor_str,subs_value)
    define
        template_str string
        ,anchor_str string
        ,subs_value string
        ,output_str string
        ,idx int
        ,tkn_idx int
    let idx = 1
    let tkn_idx = template_str.getIndexOf(anchor_str,1)
   
    while tkn_idx <> 0
        let output_str = output_str, template_str.subString(idx,tkn_idx-1),subs_value
        #move index to position after anchor
        let idx = tkn_idx + anchor_str.getLength()
        #look for next anchor
        let tkn_idx = template_str.getIndexOf(anchor_str,idx)
    end while
    #add last part of string
    let output_str = output_str,template_str.subString(idx,template_str.getLength())
    return output_str
end function

