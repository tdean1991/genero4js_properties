# properties
An Genero/Informix class to handle java style properties xml files.

One issue with Genero BDL was the lack of a properties module that allowed you to update settings without recompiling. 

Because of this, I've developed a properties module that provides methods to load settings from an XML schema.  The XML schema is based upon the Java properties file XML specification.  

The module can be initialized with a load_xml_file function that will read the settings from the properties file.  Once loaded, the data can be read from a dictionary data structure.  
