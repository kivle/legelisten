Import-Module $psscriptroot\PowerHTML\PowerHTML.psm1

$baseUrl = "https://www.legelisten.no/leger/Rogaland/Stavanger?side="
$utf8 = [System.Text.Encoding]::UTF8
$default = [System.Text.Encoding]::Default

function ScrapePage($pageNumber) {
  $result = Invoke-Webrequest "$baseUrl$pageNumber"
  $bytes = $utf8.GetBytes($result.Content)
  $convertedBytes = [System.Text.Encoding]::Convert($utf8, $default, $bytes)
  $converted = $default.GetString($convertedBytes)
  $doc = ConvertFrom-Html $converted
  $rows = $doc.SelectNodes("/html/body/main/section[3]/div/div/table/tbody/tr")
  if (!$rows -or $rows.Count -eq 0) {
    return @()
  }
  $list = @($rows | ForEach-Object {
    try {
      if ($psitem.HasClass("inline-ad")) {
        return
      }
      $rating = $psitem.SelectSingleNode("td[2]/div/a/div/div[1]/span").InnerText.Trim()
      $reviewCount = $psitem.SelectSingleNode("td[2]/div/a/div/div[3]").InnerText.Replace("vurderinger", "").Trim()
      $name = $psitem.SelectSingleNode("td[3]/span[1]/a").InnerText.Trim()
      $sexAndAge = ($psitem.SelectSingleNode("td[3]/span[2]").InnerText) -split ","
      $sex = $sexAndAge[0].Trim()
      $age = $sexAndAge[1].Replace("år", "").Trim()
      $company = $psitem.SelectSingleNode("td[4]/span[1]/a").InnerText.Trim()
      $address = $psitem.SelectSingleNode("td[4]/span[2]/span").InnerText.Trim()
      $availability = $psitem.SelectSingleNode("td[6]/button/span/span[2]/span[1]").InnerText.Replace("&nbsp;plasser", "").Trim()

      [pscustomobject]@{
        rating=$rating;
        reviewCount=$reviewCount;
        name=$name;
        sex=$sex;
        age=$age;
        company=$company;
        address=$address;
        availability=$availability;
      }
    }
    catch {}
  })
  return $list
}

$page = 1
$all = @()

while($true) {
  $list = ScrapePage $page
  if ($list.Count -eq 0) {
    break
  }
  $all += $list
  $page += 1
}

$json = $all | sort-object { $psitem.name } | convertto-json -depth 10
$json > "data.json"
