<?php
$wgHooks['ParserFirstCallInit'][] = 'bdParserFunction_Setup';   # Define a setup function
$wgHooks['LanguageGetMagic'][]    = 'bdParserFunction_Magic';   # Add a hook to initialise the magic word
 
function bdParserFunction_Setup( &$parser ) {
 $parser->setFunctionHook('file', 'bdParserFunction_Render');
 return true;
}
 
function bdParserFunction_Magic( &$magicWords, $langCode ) {
  # The first array element: (0) is not case sensitive, (1) is case sensitive
  $magicWords['file'] = array( 0, 'file' );
  return true;
}
 
function bdParserFunction_Render( $parser, $filename = '', $link_text = "BAMRU File" ) {
  # The input parameters are wikitext with templates expanded
  # The output should be wikitext too
  $tmp_array  = explode('.', $filename);
  $tmp_ext    = end($tmp_array);
  $extension  = strtolower($tmp_ext);
  $output = "[http://bamru.net/files/$filename $link_text] [$extension]";
  return $output;
}
