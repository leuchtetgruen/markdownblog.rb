<?php
function check_if_spider() {
	// Add as many spiders you want in this array
	$spiders = array('Googlebot', 'Yammybot', 'Openbot', 'Yahoo', 'Slurp', 'msnbot', 'ia_archiver', 'Lycos', 'Scooter', 'AltaVista', 'Teoma', 'Gigabot', 'Googlebot-Mobile');

	// Loop through each spider and check if it appears in
	// the User Agent
	foreach ($spiders as $spider)
	{
		if (eregi($spider, $_SERVER['HTTP_USER_AGENT']))
		{
			return TRUE;
		}
	}
	return FALSE;
}


if (check_if_spider()) {
	$hash = $_GET['post'];
	if ($hash=="") {
		$xml = simplexml_load_file("../../content/feed.rss");
		echo "<h1>" . $xml->channel->title . "</h1>\t\n";
		foreach ($xml->channel->item as $item) {
			echo "<h2><a href='" . $item->link . "'>". $item->title . "</a></h2><br/>\r\n";
			echo "<p>" . $item->description . "</p>\r\n";
		}
		exit;
		
	}
	else {
		$a_map = json_decode(file_get_contents("../../content/map.json"), true);
		$filename = $a_map[$hash];

		echo file_get_contents("../../content/" . $filename);
		exit;
	}
}
else {
	if ($_SERVER['SERVER_PORT']!=80) $port = ":" + $_SERVER['SERVER_PORT'];
	else $port = "";
	$url = "http://" . $_SERVER['SERVER_NAME'] . $port;
	
	$a_paths = explode("/", $_SERVER['REQUEST_URI']);
	foreach ($a_paths as $path) {
		if ($path=="plugins") break;
		$url .= "/";
		$url .= $path;
	}
	$url .= "/index.html#!" . $_GET['post'];
	
	header("Location: " . $url);
}
?>