from ocrd.constants import NAMESPACES
from ocrd.utils import xmllint_format

from lxml import etree as ET

for curie in NAMESPACES:
    ET.register_namespace(curie, NAMESPACES[curie])

class OcrdXmlDocument(object):

    def __init__(self, filename=None, content=None):
        #  print(self, filename, content)
        if filename is None and content is None:
            raise Exception("Must pass 'filename' or 'content' to " + self.__class__.__name__)
        elif content:
            self._tree = ET.XML(content.encode('utf-8'), parser=ET.XMLParser(encoding='utf-8'))
        else:
            self._tree = ET.ElementTree()
            self._tree.parse(filename)

    def to_xml(self, xmllint=False):
        root = self._tree
        if hasattr(root, 'getroot'):
            root = root.getroot()
        ret = ET.tostring(ET.ElementTree(root), pretty_print=True)
        if xmllint:
            ret = xmllint_format(ret)
        return ret
