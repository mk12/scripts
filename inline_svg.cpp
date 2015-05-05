#include <fstream>
#include <iostream>
#include <string>

int main(int argc, char* argv[]) {
	if (argc != 2) {
		std::cerr << "usage: inline_svg IMAGES_PATH\n";
		return 1;
	}
	std::string line;
	while (std::getline(std::cin, line)) {
		auto pos = line.find("<img src=\"");
		bool svg = false;
		if (pos != std::string::npos) {
			auto end = line.find('\"', pos + 10);
			if (end != std::string::npos) {
				auto start = line.rfind('/', end);
				if (start != std::string::npos) {
					std::string name = line.substr(start + 1, end - start - 1);
					auto len = name.length();
					if (len > 4 && name[len-4] == '.' && name[len-3] == 's'
							&& name[len-2] == 'v' &&  name[len-1] == 'g') {
						svg = true;
						std::string path(argv[1]);
						if (path.back() != '/') {
							path.push_back('/');
						}
						path += name;
						std::ifstream file(path.c_str());
						if (!file) {
							std::cerr << "could not open file '" << path << "'\n";
							return 1;
						}
						// Consume xml and DOCTYPE lines.
						// std::string dummy;
						// getline(file, dummy);
						// getline(file, dummy);
						std::cout << file.rdbuf();
					}
				}
			}
		}
		if (!svg) {
			std::cout << line;
		}
		std::cout << '\n';
	}
	return 0;
}
