<?php
// For the google crawler
if (isset($_GET['_escaped_fragment_'])) {
	$hash = $_GET['_escaped_fragment_'];
	if ($hash=="") {
		$xml = simplexml_load_file("content/feed.rss");
		echo "<h1>" . $xml->channel->title . "</h1>\t\n";
		foreach ($xml->channel->item as $item) {
			echo "<h2><a href='" . $item->link . "'>". $item->title . "</a></h2><br/>\r\n";
			echo "<p>" . $item->description . "</p>\r\n";
		}
		exit;
		
	}
	else {
		$a_map = json_decode(file_get_contents("content/map.json"), true);
		$filename = $a_map[$hash];

		echo file_get_contents("content/" . $filename);
		exit;
	}
}
else {
	// XXX TODO - get real values
	$url = "http://foo.bar/";
	$argument = "foobar";
	header("Location: " + $url + "/index.html#!" + $argument);
}
?>