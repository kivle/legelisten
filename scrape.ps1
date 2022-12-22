Import-Module $psscriptroot\PowerHTML\PowerHTML.psm1

$baseUrl = "https://www.legelisten.no/leger/Rogaland/Stavanger?side="
$baseUrl2 = "https://www.legelisten.no"
$utf8 = [System.Text.Encoding]::UTF8
$default = [System.Text.Encoding]::Default

function GetUrl($url) {
  $result = Invoke-Webrequest $url
  $bytes = $utf8.GetBytes($result.Content)
  $convertedBytes = [System.Text.Encoding]::Convert($utf8, $default, $bytes)
  $converted = $default.GetString($convertedBytes)
  return ConvertFrom-Html $converted
}

function GetNodeInnerText($base, $selector) {
  $node = $base.SelectSingleNode($selector)
  if ($node) {
    return $node.InnerText
  }
  return ""
}

function ScrapePage($pageNumber) {
  $doc = GetUrl "$baseUrl$pageNumber"
  $rows = $doc.SelectNodes("/html/body/main/section[3]/div/div/table/tbody/tr")
  if (!$rows -or $rows.Count -eq 0) {
    return @()
  }
  $list = @($rows | ForEach-Object {
    try {
      if ($psitem.HasClass("inline-ad")) {
        return
      }
      $rating = (GetNodeInnerText $psitem "td[2]/div/a/div/div[1]/span").Trim()
      $reviewCount = (GetNodeInnerText $psitem "td[2]/div/a/div/div[3]").Replace("vurderinger", "").Replace("vurdering", "").Trim()
      $name = (GetNodeInnerText $psitem "td[3]/span[1]/a").Trim()
      $linkNode = $psitem.SelectSingleNode("td[3]/span[1]/a")
      $sexAndAge = (GetNodeInnerText $psitem "td[3]/span[2]") -split ","
      $sex = $sexAndAge[0].Trim()
      $age = $sexAndAge[1].Replace("år", "").Trim()
      $company = (GetNodeInnerText $psitem "td[4]/span[1]/a").Trim()
      $address = (GetNodeInnerText $psitem "td[4]/span[2]/span").Trim()
      $availability = ((GetNodeInnerText $psitem "td[6]/button/span/span[2]/span[1]").
                        Replace("&nbsp;plasser", "").
                        Replace("ledige&nbsp;plasser", "").
                        Replace("ledige plasser", "").
                        Replace("Venteliste", "0").
                        Trim()
      )

      $waitingList = "n/a"
      if ($linkNode -and $linkNode.Attributes["href"]) {
        $link = $linkNode.Attributes["href"].Value
        $doc2 = GetUrl "$baseUrl2$link"
        $waitingListLabel = $doc2.SelectNodes("/html/body/main/section[1]/div/div[2]/div/div/h3[text() = 'Venteliste']")
        if ($waitingListLabel) {
          $waitingList = ($waitingListLabel.ParentNode.ParentNode.SelectSingleNode("div[2]").InnerText.
                        Replace("personer", "").
                        Replace("Ingen på venteliste", "0").
                        Replace("Låst – ingen venteliste", "n/a").
                        Trim()
          )
        }
        Start-Sleep -Seconds 1
      }

      [pscustomobject]@{
        rating=$rating;
        reviewCount=$reviewCount;
        name=$name;
        sex=$sex;
        age=$age;
        company=$company;
        address=$address;
        availability=$availability;
        waitingList=$waitingList;
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
  Start-Sleep -Seconds 5
}

if ($all.Count -gt 0) {
  $json = $all | sort-object { $psitem.name } | convertto-json -depth 10
  $json > "data.json"
}
